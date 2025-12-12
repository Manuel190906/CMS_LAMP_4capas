#!/bin/bash

# Script de aprovisionamiento del Proxy de Base de Datos HAProxy
# Capa 3 - Balanceador de bases de datos

echo "=== Actualizando sistema ==="
apt-get update

# Instalación de mariadb para clientes
echo "=== Instalando HAProxy ==="
apt-get install -y haproxy mariadb-client

echo "=== Configurando HAProxy para balanceo de bases de datos ==="
cat > /etc/haproxy/haproxy.cfg <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

listen mysql-cluster
    bind *:3306
    mode tcp
    balance roundrobin
    option mysql-check user haproxy
    server db1 192.168.40.11:3306 check
    server db2 192.168.40.12:3306 check

listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats realm HAProxy\ Statistics
    stats auth admin:admin
EOF

echo "=== Habilitando HAProxy ==="
systemctl enable haproxy
systemctl restart haproxy

echo "=== Proxy de base de datos configurado correctamente ==="
echo "=== Estadísticas disponibles en http://192.168.20.10:8080/stats (admin/admin) ==="