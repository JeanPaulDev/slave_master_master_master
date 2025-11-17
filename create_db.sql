-- Crea la base de datos de prueba
CREATE DATABASE IF NOT EXISTS TEST;

-- ... (Creación de tabla)

-- Crea el usuario de replicación
CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'replicontra123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;