const mariadb = require('mariadb');

// --- Configuración de las dos Bases de Datos ---

// db1: Acceso por el puerto 3306 (Maestro 1)
const dbConfig1 = {
    host: 'localhost', 
    port: 3306,        
    user: 'root',
    password: '123',   
    database: 'TEST',  
};

// db2: Acceso por el puerto 3307 (Maestro 2)
const dbConfig2 = {
    host: 'localhost', 
    port: 3307,        
    user: 'root',
    password: '456',   
    database: 'TEST',  
};

// --- Función de Inserción Concurrente ---
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
        
        // Datos para el campo 'nombre'
        const nombre1 = 'DB1-M1 Concurrente: x' + new Date().toISOString();
        const nombre2 = 'DB2-M2 Concurrente: x' + new Date().toISOString();
        
        // CORRECCIÓN CLAVE: Usamos UNHEX(REPLACE(UUID(), '-', '')) para generar BINARY(16)
        const sql = 'INSERT INTO usuarios (id, nombre) VALUES (UNHEX(REPLACE(UUID(), "-", "")), ?)'; 

        console.log('--- Iniciando 2 Inserciones Simultáneas (Una en cada Maestro) ---');
        
        // 3. Ejecutar ambas consultas en paralelo
        const [result1, result2] = await Promise.all([
            // Inserción en Maestro 1 (3306)
            conn1.query(sql, [nombre1]), 
            // Inserción en Maestro 2 (3307)
            conn2.query(sql, [nombre2])
        ]);
        
        // Confirmamos el éxito basado en las filas afectadas (affectedRows)
        console.log(`✅ Inserción en DB1 (3306) completada. Filas afectadas: ${result1.affectedRows}. Nombre: "${nombre1}"`);
        console.log(`✅ Inserción en DB2 (3307) completada. Filas afectadas: ${result2.affectedRows}. Nombre: "${nombre2}"`);

        console.log('\n--- PRUEBA EXITOSA ---');
        console.log('Ambas inserciones se realizaron simultáneamente. Si la réplica es exitosa, cada base de datos debería tener 2 nuevas filas.');

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