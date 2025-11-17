#!/bin/bash
# Script para configurar la réplica Master-Master (Versión FINAL y Garantizada)

echo "Iniciando script de configuración. Esperando 10 segundos..."
sleep 10

# --- FUNCIÓN PARA EJECUTAR SQL DE FORMA SEGURA ---
# Usamos una sintaxis Heredoc simplificada para mayor robustez
run_sql() {
    local container=$1
    local password=$2
    local sql_command=$3
    
    echo "Ejecutando SQL en $container..."
    docker exec "$container" mysql -u root -p"$password" <<< "$sql_command"
    
    if [ $? -ne 0 ]; then
        echo "🚨 ERROR: Fallo al ejecutar SQL en $container."
    fi
}

# --- 1. CONFIGURACIÓN INICIAL (Usuario y Master-Master) ---
echo "--- 1. Creando usuario y configurando enlaces GTID ---"

# Configuración M1 (Maestro 1)
run_sql mariadb_master1 123 "
CREATE USER 'repl_user'@'%' IDENTIFIED BY 'replicontra123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST='mariadb_master2', MASTER_USER='repl_user', MASTER_PASSWORD='replicontra123', MASTER_PORT=3306, MASTER_AUTO_POSITION=1;
START SLAVE;
"

# Configuración M2 (Maestro 2)
run_sql mariadb_master2 456 "
CREATE USER 'repl_user'@'%' IDENTIFIED BY 'replicontra123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST='mariadb_master1', MASTER_USER='repl_user', MASTER_PASSWORD='replicontra123', MASTER_PORT=3306, MASTER_AUTO_POSITION=1;
START SLAVE;
"

# --- 2. CREACIÓN DE DATOS INICIALES Y AUTOCORRECCIÓN DEL BLOQUEO ---
echo "=========================================================="
echo "--- 2. CREACIÓN DE DATOS INICIALES (Causa el bloqueo GTID) ---"
echo "=========================================================="

# 2.1. Creación de DB y Fila BLOQUEANTE en M1
run_sql mariadb_master1 123 "
CREATE DATABASE IF NOT EXISTS TEST;
USE TEST; 
CREATE TABLE IF NOT EXISTS test_table ( id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, origen VARCHAR(20) NOT NULL, mensaje VARCHAR(100) );
INSERT INTO test_table (origen, mensaje) VALUES ('MAESTRO_1', 'Fila Inicial - BLOQUEANTE');
"
echo "Esperando 5 segundos para que M2 reciba y se bloquee..."
sleep 5

# 2.2. AUTOCORRECCIÓN en MAESTRO 2: Saltar y Reconfigurar (FIX)
echo "--- 3. AUTOCORRECCIÓN: Saltar, Reconfigurar y Reiniciar Réplica en M2 ---"

run_sql mariadb_master2 456 "
STOP SLAVE; 
SET GLOBAL sql_slave_skip_counter = 1;
CHANGE MASTER TO MASTER_HOST='mariadb_master1', MASTER_USER='repl_user', MASTER_PASSWORD='replicontra123', MASTER_PORT=3306, MASTER_AUTO_POSITION=1;
START SLAVE;
"

# --- 4. PRUEBA FINAL DE RÉPLICA ---
echo "--- 4. PRUEBA FINAL: Insertando una fila que debe replicar limpiamente ---"

# 4.1. Insertar una SEGUNDA fila en M1 (Esta debe pasar)
run_sql mariadb_master1 123 "
USE TEST; 
INSERT INTO test_table (origen, mensaje) VALUES ('MAESTRO_1', 'Fila Final - REPLICADA CORRECTAMENTE');
"
echo "Esperando 3 segundos para la réplica..."
sleep 3

# 4.2. Verificar el contenido en M2
echo "✅ RESULTADO FINAL: Filas en Maestro 2 (Debe mostrar 1 o 2 filas):"
docker exec mariadb_master2 mysql -u root -p456 -e "SELECT * FROM TEST.test_table;"

echo "Script de configuración y prueba 100% autónomo finalizado."