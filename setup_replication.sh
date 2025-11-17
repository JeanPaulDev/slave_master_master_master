#!/bin/bash
# Script para configurar la réplica Master-Master con esquema UUID (MariaDB 10.6 compatible)

echo "Iniciando script de configuración. Esperando 10 segundos..."
sleep 10

# --- FUNCIÓN PARA EJECUTAR SQL DE FORMA SEGURA ---
run_sql() {
    local container=$1
    local password=$2
    local sql_command=$3
    
    echo "Ejecutando SQL en $container..."
    # Ejecutamos con la opción -s (silent) para suprimir output innecesario y -e (execute)
    docker exec "$container" mysql -u root -p"$password" -e "$sql_command"
    
    if [ $? -ne 0 ]; then
        echo "🚨 ERROR CRÍTICO: Fallo al ejecutar SQL en $container."
        echo "Comando: $sql_command"
    fi
}

# --- FUNCIÓN PARA GENERAR UUID EN FORMATO BINARY(16) COMPATIBLE CON MARIA DB 10.6 ---
# La función UUID_TO_BIN no existe. Usamos UNHEX(REPLACE(UUID(), '-', ''))
generate_uuid_sql() {
    # Comando SQL para generar un UUID y convertirlo a BINARY(16)
    echo "UNHEX(REPLACE(UUID(), '-', ''))"
}

# --- FUNCIÓN PARA LEER BINARY(16) COMO UUID EN FORMATO STRING ---
# La función BIN_TO_UUID no existe. Usamos manipulación de strings.
display_uuid_sql() {
    echo "INSERT(INSERT(INSERT(INSERT(HEX(id),9,0,'-'),13,0,'-'),17,0,'-'),21,0,'-') AS id_uuid"
}


# --- 1. CONFIGURACIÓN DE ENLACES GTID (Master-Master) ---
echo "=========================================================="
echo "--- 1. Configurando enlaces GTID (Master-Master) ---"
echo "=========================================================="

# Configuración M1 (Maestro 1)
run_sql mariadb_master1 123 "STOP SLAVE; CHANGE MASTER TO MASTER_HOST='mariadb_master2', MASTER_USER='repl_user', MASTER_PASSWORD='replicontra123', MASTER_PORT=3306, MASTER_AUTO_POSITION=1; START SLAVE;"

# Configuración M2 (Maestro 2)
run_sql mariadb_master2 456 "STOP SLAVE; CHANGE MASTER TO MASTER_HOST='mariadb_master1', MASTER_USER='repl_user', MASTER_PASSWORD='replicontra123', MASTER_PORT=3306, MASTER_AUTO_POSITION=1; START SLAVE;"


# --- 2. CREACIÓN DE ESQUEMA (Solo en M1) ---
echo "=========================================================="
echo "--- 2. CREACIÓN DE DB y TABLA 'usuarios' (Solo en M1) ---"
echo "=========================================================="

# 2.1. Creación de DB y Tabla 'usuarios' con UUID
# Usamos el comando -e de Docker de forma más robusta, ejecutando todas las sentencias de esquema juntas.
SCHEMA_SQL="
CREATE DATABASE IF NOT EXISTS TEST;
USE TEST; 
CREATE TABLE IF NOT EXISTS usuarios (
    id BINARY(16) PRIMARY KEY NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"
# Ejecutamos todo el bloque de creación
run_sql mariadb_master1 123 "${SCHEMA_SQL}"

echo "Esperando 5 segundos para que M2 reciba la réplica del esquema..."
sleep 5


# --- 3. PRUEBA DE RÉPLICA M1 -> M2 (Inserción en M1) ---
echo "=========================================================="
echo "--- 3. PRUEBA: Insertando Fila 1 en M1 (Debe replicar a M2) ---"
echo "=========================================================="

# Insertamos un registro en M1 usando el generador de UUID compatible.
INSERT_SQL="USE TEST; INSERT INTO usuarios (id, nombre) VALUES ($(generate_uuid_sql), 'Usuario M1 Replicado');"
run_sql mariadb_master1 123 "${INSERT_SQL}"

echo "Esperando 5 segundos para la réplica..."
sleep 5

# 3.1. Verificar el contenido en M2
echo "✅ RESULTADO PARCIAL: Filas en Maestro 2 (Debe mostrar 1 fila):"
docker exec mariadb_master2 mysql -u root -p456 -e "SELECT $(display_uuid_sql), nombre, creado_en FROM TEST.usuarios;"


# --- 4. PRUEBA DE RÉPLICA CRUZADA M2 -> M1 (Inserción en M2) ---
echo "=========================================================="
echo "--- 4. PRUEBA CRUZADA: Insertando Fila 2 en M2 (Debe replicar a M1) ---"
echo "=========================================================="
# Insertamos un segundo registro en M2.
INSERT_SQL="USE TEST; INSERT INTO usuarios (id, nombre) VALUES ($(generate_uuid_sql), 'Usuario M2 Replicado');"
run_sql mariadb_master2 456 "${INSERT_SQL}"

echo "Esperando 3 segundos para la réplica..."
sleep 3

# 4.1. Verificar el contenido en M1 (Debe mostrar 2 filas)
echo "✅ RESULTADO FINAL: Filas en Maestro 1 (Debe mostrar 2 filas):"
docker exec mariadb_master1 mysql -u root -p123 -e "SELECT $(display_uuid_sql), nombre, creado_en FROM TEST.usuarios;"

echo "Script de configuración y prueba Master-Master con UUID finalizado."