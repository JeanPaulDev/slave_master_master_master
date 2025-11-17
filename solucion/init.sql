-- init.sql
-- Solo crea el usuario de réplica y sus privilegios.
CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'replicontra123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;