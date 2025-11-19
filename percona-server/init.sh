# 1. Limpieza total de los volúmenes (si no lo hiciste en la explicación anterior)
docker compose down -v

# 2. Inicia pxc1 con el comando de bootstrap forzado.
docker compose up -d pxc1 --no-deps --force-recreate

# 3. Forzamos el bootstrap dentro del contenedor.
docker exec pxc1 /usr/bin/galera_new_cluster

# 4. Esperamos a que pxc1 esté Healthy (30 segundos)
echo "Esperando 30 segundos a que el nodo fundador inicie..."
sleep 30

# 5. Iniciamos los demás nodos
echo "Iniciando nodos joiner (pxc2, pxc3, phpMyAdmin)..."
docker compose up -d pxc2 pxc3 phpmyadmin1 phpmyadmin2

# 6. Espera y Verificación Final (120 segundos)
echo "Esperando 120 segundos para la sincronización total del clúster..."
sleep 120
echo "Verificando el tamaño final del clúster (debe ser 3):"
docker exec pxc1 mysql -u root -ppxc_root_password -e "SHOW STATUS LIKE 'wsrep_cluster_size';"