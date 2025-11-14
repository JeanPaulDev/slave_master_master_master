// concurrentInsert.js

const mariadb = require('mariadb');

// --- Configuración de las dos Bases de Datos ---

// db: Acceso por el puerto 3306
const dbConfig1 = {
    host: 'localhost', 
    port: 3306,        
    user: 'root',
    password: '123',   
    database: 'test',  // Asegúrate que esta BD y la tabla 'test' existan
};

// db2: Acceso por el puerto 3307
const dbConfig2 = {
    host: 'localhost', 
    port: 3307,        
    user: 'root',
    password: '456',   
    database: 'test',  // Asegúrate que esta BD y la tabla 'test' existan
};

// --- Función de Inserción ---
async function concurrentInsert() {
    let conn1, conn2;
    try {
        console.log('Intentando conectar y ejecutar inserciones concurrentes...');
        
        // 1. Crear conexiones en paralelo
        [conn1, conn2] = await Promise.all([
            mariadb.createConnection(dbConfig1),
            mariadb.createConnection(dbConfig2)
        ]);
        
        // 2. Definir los datos y la consulta SQL
        const data1 = ['DB1-Maestra, Hora: '+ new Date().toISOString()];
        const data2 = ['DB2-Esclava, Hora: '+ new Date().toISOString()];
        
        // ASUMIMOS que la tabla 'test' tiene columnas: 'columna_texto' y 'columna_tiempo'
        const sql = 'INSERT INTO test (text) VALUES (?)'; 

        console.log('--- Iniciando Inserciones Concurrentes ---');
        
        // 3. Ejecutar ambas consultas en paralelo
        const [result1, result2] = await Promise.all([
            conn1.query(sql, data1),
            conn2.query(sql, data2)
        ]);
        
        console.log(`✅ Inserción en DB1 (3306) completada. ID: ${result1.insertId}`);
        console.log(`✅ Inserción en DB2 (3307) completada. ID: ${result2.insertId}`);

    } catch (err) {
        // Muestra el error de forma legible
        console.error('❌ Ocurrió un error durante la conexión o inserción:', err.message || err);
        console.error('Asegúrate de que los contenedores estén corriendo y los puertos 3306/3307 estén mapeados.');
    } finally {
        // 4. Cerrar las conexiones
        if (conn1) conn1.end();
        if (conn2) conn2.end();
    }
}

concurrentInsert();