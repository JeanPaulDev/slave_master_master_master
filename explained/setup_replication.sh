#!/bin/bash
# Script para configurar la réplica Master-Master con esquema UUID (MariaDB 10.6 compatible)

echo "Iniciando script de configuración. Esperando 10 segundos..."
sleep 10

# --- FUNCIÓN PARA EJECUTAR SQL DE FORMA SIMPLE Y SEGURA ---
run_sql() {
    local container=$1
    local password=$2
    local sql_command=$3
    
    echo "Ejecutando SQL en $container..."
    # Ejecuta el comando SQL en el contenedor usando 'docker exec'
    docker exec "$container" mysql -u root -p"$password" -e "$sql_command"
    
    if [ $? -ne 0 ]; then
        echo "🚨 ERROR CRÍTICO: Fallo al ejecutar SQL en $container."
        echo "Comando: $sql_command"
        exit 1
    fi
}

# --- FUNCIONES DE UUID PARA MARIA DB 10.6 ---
# La clave es que MariaDB 10.6 no tiene UUID_TO_BIN, así que debemos hacerlo manualmente.
generate_uuid_sql() {
    # Genera el UUID, quita los guiones (-) y usa UNHEX para convertirlo en BINARY(16).
    echo "UNHEX(REPLACE(UUID(), '-', ''))"
}

display_uuid_sql() {
    # Convierte el BINARY(16) de nuevo a formato string UUID (CHAR(36)) para la visualización.
    echo "INSERT(INSERT(INSERT(INSERT(HEX(id),9,0,'-'),13,0,'-'),17,0,'-'),21,0,'-') AS id_uuid"
}

# --- FUNCIÓN PARA ESPERAR A QUE EL ESCLAVO ESTÉ LISTO ---
wait_for_slave() {
    local container=$1
    local password=$2
    local timeout=30
    local start_time=$(date +%s)

    echo "Esperando que la réplica I/O y SQL esté 'Yes' en $container (Máx $timeout s)..."

    while true; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            echo "🚨 ERROR: Tiempo de espera agotado para la réplica en $container."
            docker exec "$container" mysql -u root -p"$password" -e "SHOW SLAVE STATUS\G"
            exit 1
        fi

        status=$(docker exec "$container" mysql -u root -p"$password" -e "SHOW SLAVE STATUS\G" 2>/dev/null)
        
        # Contamos las coincidencias de "Yes" para los hilos de réplica.
        io_running_count=$(echo "$status" | grep -c "Slave_IO_Running: Yes")
        sql_running_count=$(echo "$status" | grep -c "Slave_SQL_Running: Yes")

        if [ "$io_running_count" -eq 1 ] && [ "$sql_running_count" -eq 1 ]; then
            echo "✅ Réplica en $container está saludable."
            break
        fi

        echo "Status de réplica no listo. IO: $io_running_count (esperado 1), SQL: $sql_running_count (esperado 1). Reintentando en 3s..."
        sleep 3
    done
}


# --- 1. CONFIGURACIÓN DE ENLACES GTID (Master-Master) ---
echo "=========================================================="
echo "--- 1. Configurando enlaces GTID (Master-Master) ---"
echo "=========================================================="

# 1.1. Resetear el estado de Master/GTID en ambos servidores (CRÍTICO)
# Esto limpia cualquier GTID o binlog residual, garantizando un inicio limpio (GTID 0-0-0).
run_sql mariadb_master1 123 "RESET MASTER;"
run_sql mariadb_master2 456 "RESET MASTER;"

# 1.2. Configuración M1 (Maestro 1)
REPLICA_M1="STOP SLAVE; CHANGE MASTER TO MASTER_HOST='mariadb_master2', MASTER_USER='repl_user', MASTER_PASSWORD='replicontra123', MASTER_PORT=3306, MASTER_USE_GTID=current_pos; START SLAVE;"
# CRÍTICO: MASTER_USE_GTID=current_pos es la sintaxis correcta para MariaDB 10.6 con GTID.
run_sql mariadb_master1 123 "${REPLICA_M1}"

# 1.3. Configuración M2 (Maestro 2)
REPLICA_M2="STOP SLAVE; CHANGE MASTER TO MASTER_HOST='mariadb_master1', MASTER_USER='repl_user', MASTER_PASSWORD='replicontra123', MASTER_PORT=3306, MASTER_USE_GTID=current_pos; START SLAVE;"
run_sql mariadb_master2 456 "${REPLICA_M2}"

# Esperar a que AMBOS enlaces estén activos antes de continuar.
wait_for_slave mariadb_master1 123
wait_for_slave mariadb_master2 456


# --- 2. CREACIÓN DE ESQUEMA (Solo en M1) ---
echo "=========================================================="
echo "--- 2. CREACIÓN DE DB y TABLA 'usuarios' (Solo en M1) ---"
echo "=========================================================="

# 2.1. Creación de DB y Tabla 'usuarios' (Ejecutado en comandos separados para robustez)
# La tabla usa BINARY(16) para UUIDs, optimizando el rendimiento y el espacio.
run_sql mariadb_master1 123 "CREATE DATABASE IF NOT EXISTS TEST;"
run_sql mariadb_master1 123 "USE TEST; CREATE TABLE IF NOT EXISTS usuarios (id BINARY(16) PRIMARY KEY NOT NULL, nombre VARCHAR(255) NOT NULL, creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

# Esperamos a que M2 reciba y aplique el DDL (CREATE TABLE).
echo "Esperando que M2 reciba la réplica del esquema..."
wait_for_slave mariadb_master2 456


# --- 3. PRUEBA DE RÉPLICA M1 -> M2 (Inserción en M1) ---
echo "=========================================================="
echo "--- 3. PRUEBA: Insertando Fila 1 en M1 (Debe replicar a M2) ---"
echo "=========================================================="

# Utilizamos generate_uuid_sql para crear el ID único en el maestro 1.
INSERT_SQL="USE TEST; INSERT INTO usuarios (id, nombre) VALUES ($(generate_uuid_sql), 'Usuario M1 Replicado');"
run_sql mariadb_master1 123 "${INSERT_SQL}"

# Esperamos la réplica.
echo "Esperando que M2 reciba la réplica de la inserción..."
wait_for_slave mariadb_master2 456

# 3.1. Verificar el contenido en M2
echo "✅ RESULTADO PARCIAL: Filas en Maestro 2 (Debe mostrar 1 fila):"
docker exec mariadb_master2 mysql -u root -p456 -e "SELECT $(display_uuid_sql), nombre, creado_en FROM TEST.usuarios;"


# --- 4. PRUEBA DE RÉPLICA CRUZADA M2 -> M1 (Inserción en M2) ---
echo "=========================================================="
echo "--- 4. PRUEBA CRUZADA: Insertando Fila 2 en M2 (Debe replicar a M1) ---"
echo "=========================================================="

# Utilizamos generate_uuid_sql para crear el ID único en el maestro 2.
INSERT_SQL="USE TEST; INSERT INTO usuarios (id, nombre) VALUES ($(generate_uuid_sql), 'Usuario M2 Replicado');"
run_sql mariadb_master2 456 "${INSERT_SQL}"

# Esperamos la réplica.
echo "Esperando que M1 reciba la réplica de la inserción..."
wait_for_slave mariadb_master1 123


# 4.1. Verificar el contenido en M1 (Debe mostrar 2 filas)
echo "✅ RESULTADO FINAL: Filas en Maestro 1 (Debe mostrar 2 filas):"
docker exec mariadb_master1 mysql -u root -p123 -e "SELECT $(display_uuid_sql), nombre, creado_en FROM TEST.usuarios;"

echo "Script de configuración y prueba Master-Master con UUID finalizado."