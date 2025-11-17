-- init.sql
-- Este script solo crea el usuario de réplica para evitar que la transacción 
-- de creación de DB/tabla se ejecute antes de configurar el GTID.

-- Crea el usuario 'repl_user' con la contraseña y permite la conexión desde cualquier host (%).
CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'replicontra123';
-- Le otorga los permisos necesarios para que sea un esclavo de réplica.
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
-- Aplica inmediatamente los cambios de privilegios.
FLUSH PRIVILEGES;

-- IMPORTANTE: La base de datos y la tabla 'usuarios' se crean en el script de shell
-- para garantizar que la réplica GTID esté activa y funcionando ANTES de la primera DDL.