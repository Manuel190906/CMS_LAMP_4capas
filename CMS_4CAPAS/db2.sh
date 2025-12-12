#!/bin/bash

# Script de aprovisionamiento del Servidor de Base de Datos 2
# Capa 4 - Datos (MariaDB Galera Cluster - Nodo 2)

echo "=== Actualizando sistema ==="
apt-get update

echo "=== Instalando MariaDB Server y Galera ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync

echo "=== Deteniendo MariaDB para configuración ==="
systemctl stop mariadb || true
killall -9 mysqld 2>/dev/null || true
sleep 3

echo "=== Configurando Galera Cluster ==="
cat > /etc/mysql/mariadb.conf.d/60-galera.cnf <<'EOF'
[mysqld]
# Configuración básica
bind-address = 0.0.0.0

# Configuración de Galera
wsrep_on = ON
wsrep_provider = /usr/lib/galera/libgalera_smm.so

# Cluster configuration
wsrep_cluster_name = "galera_cluster"
wsrep_cluster_address = "gcomm://192.168.40.11,192.168.40.12"

# Node configuration
wsrep_node_address = "192.168.40.11"
wsrep_node_name = "serverdatos2ManuelR"

# SST method
wsrep_sst_method = rsync

# Configuración para replicación
binlog_format = row
default_storage_engine = InnoDB
innodb_autoinc_lock_mode = 2
EOF

echo "=== Limpiando estado previo de Galera ==="
rm -f /var/lib/mysql/grastate.dat

echo "=== Esperando a que el nodo 1 esté disponible ==="
echo "Esperando 40 segundos para que el cluster se inicialice en db1..."
sleep 40

echo "=== Iniciando MariaDB y uniéndose al cluster ==="
systemctl start mariadb

echo "=== Esperando a que MariaDB esté disponible ==="
sleep 15

# Verificar que MariaDB está corriendo
echo "=== Verificando estado del cluster ==="
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';" || echo "Esperando sincronización..."
sleep 5
mysql -e "SHOW STATUS LIKE 'wsrep_ready';" || echo "Esperando sincronización..."

echo "=== Verificando replicación de datos ==="
mysql -e "USE cms_lamp_db; SHOW TABLES;" 2>/dev/null || echo "Base de datos aún sincronizando..."
# Lo mandamos en segundo plano mientras se ejecuta
sleep 3
mysql -e "USE cms_lamp_db; SELECT * FROM usuarios LIMIT 5;" 2>/dev/null || echo "Tablas aún sincronizando..."

echo "=== Habilitando MariaDB para su uso ==="
systemctl enable mariadb

echo "=== Servidor de base de datos 2 (Galera Nodo 2) configurado correctamente ==="
echo "=== Estado del cluster: ==="
mysql -e "SHOW STATUS LIKE 'wsrep_%';" 2>/dev/null | grep -E "wsrep_cluster_size|wsrep_cluster_status|wsrep_ready|wsrep_connected" || echo "Nodo uniéndose al cluster..."