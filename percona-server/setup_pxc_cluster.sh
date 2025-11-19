
#!/bin/bash
# Script para configurar y verificar el clúster Percona XtraDB (PXC)

echo "Iniciando script de validación. Esperando 15 segundos para la formación inicial..."
sleep 15

# --- Configuración ---
ROOT_PASS="pxc_root_password"
PXC_NODE="pxc1" # Usaremos pxc1 para la mayoría de las operaciones

# --- FUNCIÓN PARA EJECUTAR SQL ---
run_sql() {
    local container=$1
    local sql_command=$2

    echo "Ejecutando SQL en $container (intentando TCP hacia la IP del contenedor)..."

    # Obtener IP del contenedor (uso de docker exec para mantenerlo portable)
    CONTAINER_IP=$(docker exec "$container" bash -c "hostname -I | awk '{print \$1}'" 2>/dev/null || true)
    if [ -z "$CONTAINER_IP" ]; then
        # Fallback a inspect si hostname -I falla
        CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || true)
    fi

    # Intentos para esperar a que el servidor acepte conexiones TCP
    local tries=0
    local max_tries=60
    while true; do
        if [ -n "$CONTAINER_IP" ]; then
            docker exec "$container" mysql -h"$CONTAINER_IP" -P3306 -u root -p"$ROOT_PASS" -e "$sql_command" && break || true
        else
            docker exec "$container" mysql -u root -p"$ROOT_PASS" -e "$sql_command" && break || true
        fi

        tries=$((tries+1))
        if [ $tries -ge $max_tries ]; then
            echo "🚨 ERROR CRÍTICO: Fallo al ejecutar SQL en $container después de $max_tries intentos."
            echo "Comando: $sql_command"
            exit 1
        fi
        echo "Esperando a que MySQL en $container acepte conexiones... intento $tries/$max_tries"
        sleep 2
    done

}

# Ejecutar SQL desde un contenedor "from" hacia la IP de un contenedor objetivo (evita sockets locales en el joiner)
run_sql_from() {
    local from_container=$1
    local target_container=$2
    local sql_command=$3

    echo "Ejecutando SQL desde $from_container hacia $target_container (TCP, con reintentos)..."
    TARGET_IP=$(docker exec "$target_container" bash -c "hostname -I | awk '{print \$1}'" 2>/dev/null || true)
    if [ -z "$TARGET_IP" ]; then
        TARGET_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$target_container" 2>/dev/null || true)
    fi

    local tries=0
    local max_tries=60
    while true; do
        docker exec "$from_container" mysql -h"$TARGET_IP" -P3306 -u root -p"$ROOT_PASS" -e "$sql_command" && break || true

        tries=$((tries+1))
        if [ $tries -ge $max_tries ]; then
            echo "🚨 ERROR CRÍTICO: Fallo al ejecutar SQL desde $from_container hacia $target_container después de $max_tries intentos."
            echo "Comando: $sql_command"
            exit 1
        fi
        echo "Esperando a que MySQL en $target_container acepte conexiones (desde $from_container)... intento $tries/$max_tries"
        sleep 2
    done
}

# --- FUNCIÓN PARA GENERAR UUID (MySQL 8.0/PXC 8.0) ---
generate_uuid_sql() {
    # Función nativa en MySQL/PXC para generar el UUID y transformarlo a BINARY(16)
    echo "UUID_TO_BIN(UUID(), 1)"
}

# --- FUNCIÓN PARA MOSTRAR UUID (MySQL 8.0/PXC 8.0) ---
display_uuid_sql() {
    # Función nativa en MySQL/PXC para transformar BINARY(16) a formato UUID legible
    echo "BIN_TO_UUID(id, 1) AS id_uuid"
}

# --- 1. VERIFICACIÓN DEL CLÚSTER ---
echo "=========================================================="
echo "--- 1. Verificando el estado del clúster PXC ---"
echo "=========================================================="

wait_for_cluster_size() {
    local expected_size=$1
    local timeout=60
    local start_time=$(date +%s)
    
    echo "Esperando que el tamaño del clúster sea $expected_size (Máx $timeout s)..."

    while true; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            echo "🚨 ERROR: Tiempo de espera agotado. El clúster no alcanzó el tamaño esperado."
            exit 1
        fi

        # Consulta el tamaño del clúster desde pxc1
        CLUSTER_SIZE=$(docker exec "$PXC_NODE" mysql -u root -p"$ROOT_PASS" -e "SHOW STATUS LIKE 'wsrep_cluster_size';" | grep 'wsrep_cluster_size' | awk '{print $2}')
        
        if [ "$CLUSTER_SIZE" -eq "$expected_size" ]; then
            echo "✅ Tamaño del clúster OK: $CLUSTER_SIZE nodos activos."
            break
        fi

        echo "Tamaño actual del clúster: $CLUSTER_SIZE. Reintentando en 5s..."
        sleep 5
    done
}

# Esperar a que los 3 nodos se unan
wait_for_cluster_size 3


# --- 2. CREACIÓN DE ESQUEMA Y TABLA (En PXC1 - Replicación Síncrona) ---
echo "=========================================================="
echo "--- 2. CREACIÓN DE DB y TABLA 'usuarios' (En PXC1) ---"
echo "=========================================================="

# La estructura de la tabla con BINARY(16) y las funciones UUID_TO_BIN/BIN_TO_UUID son compatibles con PXC 8.0 (MySQL 8.0)
run_sql "$PXC_NODE" "CREATE DATABASE IF NOT EXISTS TEST;"
run_sql "$PXC_NODE" "USE TEST; CREATE TABLE IF NOT EXISTS usuarios (id BINARY(16) PRIMARY KEY NOT NULL, nombre VARCHAR(255) NOT NULL, creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

# En PXC, esta creación ya se ha replicado síncronamente a pxc2 y pxc3.


# --- 3. PRUEBA DE CONSISTENCIA (Inserción en PXC1, Verificación en PXC2) ---
echo "=========================================================="
echo "--- 3. PRUEBA: Insertando Fila 1 en PXC1 (Verificando en PXC2) ---"
echo "=========================================================="

INSERT_SQL="USE TEST; INSERT INTO usuarios (id, nombre) VALUES ($(generate_uuid_sql), 'Usuario PXC1 Sincrono');"
run_sql "$PXC_NODE" "${INSERT_SQL}"

# 3.1. Verificar el contenido en PXC2 (La inserción debe ser inmediata)
echo "✅ RESULTADO PARCIAL: Filas en Nodo 2 (Debe mostrar 1 fila):"
run_sql_from pxc1 pxc2 "SELECT $(display_uuid_sql), nombre, creado_en FROM TEST.usuarios;"


# --- 4. PRUEBA DE CONSISTENCIA CRUZADA (Inserción en PXC3, Verificación en PXC1) ---
echo "=========================================================="
echo "--- 4. PRUEBA CRUZADA: Insertando Fila 2 en PXC3 (Verificando en PXC1) ---"
echo "=========================================================="

INSERT_SQL="USE TEST; INSERT INTO usuarios (id, nombre) VALUES ($(generate_uuid_sql), 'Usuario PXC3 Sincrono');"
run_sql_from pxc1 pxc3 "${INSERT_SQL}"

# 4.1. Verificar el contenido en PXC1 (Debe mostrar 2 filas inmediatamente)
echo "✅ RESULTADO FINAL: Filas en Nodo 1 (Debe mostrar 2 filas):"
run_sql pxc1 "SELECT $(display_uuid_sql), nombre, creado_en FROM TEST.usuarios;"

echo "Script de validación del clúster Percona XtraDB finalizado."