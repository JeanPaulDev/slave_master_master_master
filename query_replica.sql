//si no es docker
STOP SLAVE;

CHANGE MASTER TO 
    MASTER_HOST = 'localhost',
    MASTER_USER = 'root', 
    MASTER_PASSWORD = '123', 
    MASTER_LOG_FILE = 'mysql-bin.000002', 
    MASTER_LOG_POS = 508;

START SLAVE;






//para docker

CHANGE MASTER TO 
    MASTER_HOST = 'db', 
    MASTER_USER = 'root', 
    MASTER_PASSWORD = '123',
    MASTER_PORT = 3306,
    MASTER_LOG_FILE = 'mysql-bin.000002', 
    MASTER_LOG_POS = 508;


    STOP SLAVE;

CHANGE MASTER TO 
    MASTER_HOST = 'db2', 
    MASTER_USER = 'root', 
    MASTER_PASSWORD = '456',
    MASTER_PORT = 3306,
    MASTER_LOG_FILE = '6446472', 
    MASTER_LOG_POS = 324;

START SLAVE;