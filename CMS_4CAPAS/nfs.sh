#!/bin/bash

# Script de aprovisionamiento del Servidor NFS con PHP-FPM
# Capa 2 - Backend (Almacenamiento compartido y motor PHP)

echo "=== Actualizando sistema ==="
apt-get update

echo "=== Instalando NFS Server, PHP-FPM y extensiones ==="
apt-get install -y nfs-kernel-server php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip unzip git

echo "=== Creando directorio compartido ==="
mkdir -p /var/www/html

echo "=== Configurando exportación NFS ==="
cat > /etc/exports <<'EOF'
/var/www/html 192.168.20.11(rw,sync,no_subtree_check,no_root_squash)
/var/www/html 192.168.20.12(rw,sync,no_subtree_check,no_root_squash)
EOF

exportfs -a

echo "=== Configurando PHP-FPM para escuchar en todas las interfaces ==="
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

# Escuchar en 0.0.0.0:9000 para aceptar conexiones remotas
sed -i 's/listen = \/run\/php\/php.*-fpm.sock/listen = 0.0.0.0:9000/' /etc/php/$PHP_VERSION/fpm/pool.d/www.conf

# Permitir conexiones solo desde los servidores web
sed -i 's/;listen.allowed_clients/listen.allowed_clients/' /etc/php/$PHP_VERSION/fpm/pool.d/www.conf
sed -i '/listen.allowed_clients/d' /etc/php/$PHP_VERSION/fpm/pool.d/www.conf
echo "listen.allowed_clients = 192.168.20.11,192.168.20.12" >> /etc/php/$PHP_VERSION/fpm/pool.d/www.conf

echo "=== Descargando aplicación de usuarios desde GitHub ==="
cd /tmp
git clone https://github.com/josejuansanchez/iaw-practica-lamp.git
cp -r iaw-practica-lamp/src/* /var/www/html/

echo "=== Configurando la base de datos en la aplicación ==="
cat > /var/www/html/config.php <<'EOF'
<?php
define('DB_HOST', '192.168.20.10:3306');
define('DB_NAME', 'cms_lamp_db');
define('DB_USER', 'ManuelR');
define('DB_PASSWORD', 'abcd');

$mysqli = mysqli_connect(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

if (!$mysqli) {
    die("Error de conexión: " . mysqli_connect_error());
}
?>
EOF

echo "=== Ajustando permisos ==="
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "=== Reiniciando servicios ==="
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server
systemctl enable php$PHP_VERSION-fpm
systemctl restart php$PHP_VERSION-fpm

echo "=== Verificando configuración PHP-FPM ==="
netstat -tlnp | grep 9000 || ss -tlnp | grep 9000

echo "=== Servidor NFS con PHP-FPM configurado correctamente ==="
echo "PHP-FPM escuchando en: 0.0.0.0:9000"
echo "NFS compartiendo: /var/www/html"