#!/bin/bash

# Script de aprovisionamiento del Servidor Web 1
# Capa 2 - Backend (Nginx + NFS)

echo "=== Actualizando sistema ==="
apt-get update

echo "=== Instalando Nginx y NFS client ==="
apt-get install -y nginx nfs-common

echo "=== Creando directorio para NFS ==="
mkdir -p /var/www/html

echo "=== Configurando montaje de NFS ==="
echo "192.168.20.13:/var/www/html /var/www/html nfs defaults 0 0" >> /etc/fstab
mount -a

echo "=== Configurando Nginx para usar PHP-FPM remoto ==="
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html;

    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 192.168.20.13:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

echo "=== Ajustando permisos ==="
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "=== Reiniciando Nginx ==="
systemctl enable nginx
systemctl restart nginx

echo "=== Servidor Web 1 configurado correctamente ==="