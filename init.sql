-- init.sql
-- Crea la base de datos de prueba y el usuario de réplica
CREATE DATABASE IF NOT EXISTS TEST;
CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'replicontra123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;

-- Crea la tabla inicial dentro de la DB TEST
USE TEST;
CREATE TABLE IF NOT EXISTS test_table ( 
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    origen VARCHAR(20) NOT NULL, 
    mensaje VARCHAR(100) 
);