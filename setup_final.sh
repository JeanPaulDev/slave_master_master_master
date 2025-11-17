#!/bin/bash
# Script de configuración ejecutado desde el host

echo "Esperando 20 segundos para la estabilización de los servicios..."
sleep 20

# --- CREACIÓN DEL USUARIO DE RÉPLICA ---
echo "Creando usuario de réplica (repl_user) en ambos maestros..."

# Conexión directa a través de puertos mapeados (3306 y 3307)

# 1. Crear usuario en Maestro 1 (Puerto 3306)
mysql -h 127.0.0.1 -P 3306 -u root -p123 -e " \
  CREATE USER 'repl_user'@'%' IDENTIFIED BY 'replicontra123'; \
  GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%'; \
  FLUSH PRIVILEGES;"

# 2. Crear usuario en Maestro 2 (Puerto 3307)
mysql -h 127.0.0.1 -P 3307 -u root -p456 -e " \
  CREATE USER 'repl_user'@'%' IDENTIFIED BY 'replicontra123'; \
  GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%'; \
  FLUSH PRIVILEGES;"

echo "Usuarios de réplica creados."

# --- CONFIGURACIÓN MASTER-MASTER ---

# 3. Maestro 1 se conecta a Maestro 2 (usando el host interno de Docker: mariadb_master2)
mysql -h 127.0.0.1 -P 3306 -u root -p123 -e " \
  STOP SLAVE; \
  CHANGE MASTER TO \
    MASTER_HOST='mariadb_master2', \
    MASTER_USER='repl_user', \
    MASTER_PASSWORD='replicontra123', \
    MASTER_PORT=3306, \
    MASTER_AUTO_POSITION=1, \
    IGNORE_SERVER_IDS=(1); \
  START SLAVE;"

# 4. Maestro 2 se conecta a Maestro 1 (usando el host interno de Docker: mariadb_master1)
mysql -h 127.0.0.1 -P 3307 -u root -p456 -e " \
  STOP SLAVE; \
  CHANGE MASTER TO \
    MASTER_HOST='mariadb_master1', \
    MASTER_USER='repl_user', \
    MASTER_PASSWORD='replicontra123', \
    MASTER_PORT=3306, \
    MASTER_AUTO_POSITION=1, \
    IGNORE_SERVER_IDS=(2); \
  START SLAVE;"

echo "=========================================================="
echo "🚀 PRUEBA DE RÉPLICA: Creación de DB 'TEST' y datos"
echo "=========================================================="

# 5. Creación de DB y Tabla en MAESTRO 1
echo "--> Creando DB 'TEST' en mariadb_master1..."
mysql -h 127.0.0.1 -P 3306 -u root -p123 -e "CREATE DATABASE IF NOT EXISTS TEST;"

echo "--> Creando tabla y datos iniciales en mariadb_master1..."
mysql -h 127.0.0.1 -P 3306 -u root -p123 -e "USE TEST; \
  CREATE TABLE IF NOT EXISTS test_table ( \
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, \
    origen VARCHAR(20) NOT NULL, \
    mensaje VARCHAR(100) \
  );"

mysql -h 127.0.0.1 -P 3306 -u root -p123 -e "USE TEST; \
  INSERT INTO test_table (origen, mensaje) VALUES ('MAESTRO_1', 'Fila creada inicialmente en M1');"

# 6. Inserción de dato en MAESTRO 2 
echo "--> Insertando fila de prueba en mariadb_master2..."
mysql -h 127.0.0.1 -P 3307 -u root -p456 -e "USE TEST; \
  INSERT INTO test_table (origen, mensaje) VALUES ('MAESTRO_2', 'Fila insertada en M2 para replicar a M1');"

echo "✅ Verificación de la tabla en ambos maestros (deben tener 2 filas):"

echo "--- Contenido en MAESTRO 1 (mariadb_master1) ---"
mysql -h 127.0.0.1 -P 3306 -u root -p123 -e "SELECT * FROM TEST.test_table;"

echo "--- Contenido en MAESTRO 2 (mariadb_master2) ---"
mysql -h 127.0.0.1 -P 3307 -u root -p456 -e "SELECT * FROM TEST.test_table;"

echo "Script de configuración y prueba finalizado."