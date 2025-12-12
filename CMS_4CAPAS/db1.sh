#!/bin/bash

# Script de aprovisionamiento del Servidor de Base de Datos 1
# Capa 4 - Datos (MariaDB Galera Cluster - Nodo 1)

echo "=== Actualización del sistema ==="
apt-get update

echo "=== Instalando MariaDB Server y Galera ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync git

echo "=== Detención de MariaDB para configuración ==="
systemctl stop mariadb || true
killall -9 mysqld 2>/dev/null || true
sleep 3

echo "=== Configuración de Galera Cluster ==="
cat > /etc/mysql/mariadb.conf.d/60-galera.cnf <<'EOF'
[mysqld]
# Configuración básica
bind-address = 0.0.0.0

# Configuración de Galera
wsrep_on = ON
wsrep_provider = /usr/lib/galera/libgalera_smm.so

# Configuración del cluster
wsrep_cluster_name = "galera_cluster"
wsrep_cluster_address = "gcomm://192.168.40.11,192.168.40.12"

# Node configuration
wsrep_node_address = "192.168.40.11"
wsrep_node_name = "serverdatos1ManuelR"

# SST method
wsrep_sst_method = rsync

# Configuración para replicación del cluster
binlog_format = row
default_storage_engine = InnoDB
innodb_autoinc_lock_mode = 2
EOF

echo "=== Limpiando estado previo de Galera ==="
rm -f /var/lib/mysql/grastate.dat

echo "=== Iniciando el cluster (bootstrap en primer nodo) ==="
galera_new_cluster

echo "=== Esperando a que MariaDB esté disponible ==="
sleep 10

# Verificar que MariaDB está corriendo
if ! systemctl is-active --quiet mariadb; then
    echo "ERROR: MariaDB no arrancó correctamente"
    systemctl status mariadb
    journalctl -u mariadb -n 50
    exit 1
fi

echo "=== Descargando script SQL de la aplicación ==="
cd /tmp
git clone https://github.com/josejuansanchez/iaw-practica-lamp.git

echo "=== Creando base de datos y usuario ==="
mysql <<'MYSQL_SCRIPT'
-- Crear la base de datos
CREATE DATABASE IF NOT EXISTS cms_lamp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario para la aplicación
CREATE USER IF NOT EXISTS 'ManuelR'@'%' IDENTIFIED BY 'abcd';
GRANT ALL PRIVILEGES ON cms_lamp_db.* TO 'ManuelR'@'%';

-- Crear usuario para HAProxy health checks
CREATE USER IF NOT EXISTS 'haproxy'@'%';

-- Crear usuario para SST (State Snapshot Transfer)
CREATE USER IF NOT EXISTS 'sstuser'@'localhost' IDENTIFIED BY 'sstpass';
GRANT RELOAD, LOCK TABLES, PROCESS, REPLICATION CLIENT ON *.* TO 'sstuser'@'localhost';

FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "=== Importando tablas desde el script SQL del repositorio ==="
mysql cms_lamp_db < /tmp/iaw-practica-lamp/db/database.sql
echo "Tablas importadas correctamente"

echo "=== Verificando estado del cluster ==="
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';" || true
mysql -e "SHOW STATUS LIKE 'wsrep_ready';" || true

echo "=== Habilitando MariaDB ==="
systemctl enable mariadb

echo "=== Mostrando tablas creadas ==="
mysql cms_lamp_db -e "SHOW TABLES;" || true

echo "=== Servidor de base de datos 1 (Galera Nodo 1) configurado correctamente ==="
echo "=== Estado del cluster: ==="
mysql -e "SHOW STATUS LIKE 'wsrep_%';" | grep -E "wsrep_cluster_size|wsrep_cluster_status|wsrep_ready|wsrep_connected" || true