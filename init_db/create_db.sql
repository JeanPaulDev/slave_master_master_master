-- Crea la base de datos de prueba
CREATE DATABASE IF NOT EXISTS TEST;

-- Asegura el uso de la base de datos TEST
USE TEST;

-- Crea la tabla 'usuarios' usando BINARY(16) para UUID
CREATE TABLE IF NOT EXISTS usuarios (
    id BINARY(16) PRIMARY KEY NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crea el usuario de replicación
CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'replicontra123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;