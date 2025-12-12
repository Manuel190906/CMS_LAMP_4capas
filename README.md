# CMS_LAMP_4capas
Instalación de CMS en arquitectura de 4 capas en alta disponibilidad.

# 📘 Documentación Técnica - Infraestructura LEMP en Alta Disponibilidad

## 📑 Índice

1. [Introducción del Proyecto](#1-introducción-del-proyecto)
2. [Arquitectura de la Infraestructura](#2-arquitectura-de-la-infraestructura)
3. [Direccionamiento IP Utilizado](#3-direccionamiento-ip-utilizado)
4. [Scripts de Aprovisionamiento](#4-Máquinas-Virtuales-y-Scripts-de-Aprovisionamiento)
   - 4.1. [Balanceador de Carga Nginx](#41-balanceador-de-carga)
   - 4.2. [Servidores Web (Web1 y Web2)](#42-servidores-web-web1)
   - 4.3. [Servidores Web (Web1 y Web2)](#42-servidores-web-web2)
   - 4.4. [Servidor NFS con PHP-FPM](#43-servidor-nfs)
   - 4.5. [Proxy de Base de Datos HAProxy](#44-proxy-de-base-de-datos)
   - 4.6. [Servidores de Base de Datos MariaDB Galera](#45-Servidor-de-Datos-1)
   - 4.6. [Servidores de Base de Datos MariaDB Galera](#45-Servidor-de-Datos-2)
6. [Verificación del Sistema](#6-verificación-del-sistema)
7. [Vídeo Demostrativo](#7-vídeo-demostrativo)

---

## 1. Introducción del Proyecto

Este proyecto despliega una **infraestructura web multi-nodo de alta disponibilidad** utilizando Vagrant y Debian Bookworm. El objetivo principal es simular un entorno de producción empresarial con las siguientes características:

### Características Principales

- **Alta disponibilidad**: redundancia en todas las capas críticas
- **Balanceo de carga**: distribución automática del tráfico web y de base de datos
- **Almacenamiento compartido**: sistema NFS para sincronización de contenido
- **Replicación de datos**: cluster MariaDB Galera con sincronización multi-maestro
- **Separación de servicios**: arquitectura en capas con redes aisladas
- **Aprovisionamiento automatizado**: despliegue completo mediante scripts Bash

### Componentes de la Infraestructura

La infraestructura se compone de **siete máquinas virtuales** que trabajan en conjunto:

1. **Balanceador de Carga Nginx**: distribuye las peticiones HTTP entre los servidores web
2. **Servidor Web 1 y 2**: procesan las peticiones y sirven contenido estático
3. **Servidor NFS + PHP-FPM**: almacena archivos compartidos y ejecuta código PHP
4. **Proxy HAProxy**: balancea las conexiones a la base de datos
5. **Servidor de Datos 1 y 2**: cluster Galera para replicación síncrona de datos

### Aplicación Desplegada

La infraestructura aloja una **aplicación de gestión de usuarios** desarrollada en PHP que permite:

- Crear, leer, actualizar y eliminar usuarios
- Gestión completa de datos mediante interfaz web
- Almacenamiento persistente en base de datos MariaDB
- Acceso desde cualquier navegador web

---

## 2. Arquitectura de la Infraestructura

### 2.1. Diagrama de Arquitectura

```
                    INTERNET / RED PÚBLICA
                           |
                    ┌──────┴──────┐
                    │   CAPA 1    │
                    │ Balanceador │  192.168.5.10 (Pública)
                    │   (Nginx)   │  192.168.10.14 (Web)
                    └──────┬──────┘  Puerto 80 → 8080
                           |
              ┌────────────┼────────────┐
              |                         |
       ┌──────┴──────┐           ┌──────┴──────┐
       │   CAPA 2    │           │   CAPA 2    │
       │ ServerWeb1  │           │ ServerWeb2  │
       │  (Nginx)    │           │  (Nginx)    │
       │192.168.10.10│           │192.168.10.11│
       │192.168.20.11│           │192.168.20.12│
       └──────┬──────┘           └──────┬──────┘
              |                         |
              └────────────┬────────────┘
                           |
                    ┌──────┴──────┐
                    │   CAPA 2    │
                    │ ServerNFS   │  192.168.10.13 (Web)
                    │ (NFS+PHP)   │  192.168.20.13 (NFS)
                    └──────┬──────┘
                           |
                    ┌──────┴──────┐
                    │   CAPA 3    │
                    │  ProxyDB    │  192.168.20.10 (NFS)
                    │  (HAProxy)  │  192.168.40.10 (DB)
                    └──────┬──────┘
                           |
              ┌────────────┼────────────┐
              |                         |
       ┌──────┴──────┐           ┌──────┴──────┐
       │   CAPA 4    │           │   CAPA 4    │
       │ServerDatos1 │◄─────────►│ServerDatos2 │
       │ (MariaDB)   │  Galera   │ (MariaDB)   │
       │192.168.40.11│Replication│192.168.40.12│
       └─────────────┘           └─────────────┘
```

### 2.2. Redes Virtuales y Segmentación

La infraestructura utiliza **cuatro redes privadas separadas** para aislar servicios y mejorar la seguridad:

| Red | Segmento | Función | Equipos Conectados |
|-----|----------|---------|-------------------|
| **Red Pública** | 192.168.5.0/24  | Acceso frontal desde Internet | Balanceador |
| **Red Web**     | 192.168.10.0/24 | Comunicación entre balanceador y servidores web | Balanceador, Web1, Web2, NFS |
| **Red NFS**     | 192.168.20.0/24 | Comunicación con NFS y acceso a proxy DB | Web1, Web2, NFS, ProxyDB |
| **Red Database**| 192.168.40.0/24 | Red exclusiva para bases de datos | ProxyDB, DB1, DB2 |

### 2.3. Descripción de Capas

#### Capa 1 - Frontend (Balanceador de Carga)

**Función**: punto de entrada único para todo el tráfico web externo.

- Recibe peticiones HTTP desde Internet
- Distribuye la carga entre los servidores web mediante algoritmo round-robin
- Implementa health checks para detectar servidores caídos
- Añade headers HTTP necesarios para el correcto funcionamiento de la aplicación

#### Capa 2 - Backend (Servidores Web y NFS)

**Función**: procesamiento de peticiones web y almacenamiento compartido.

**Servidores Web**:
- Procesan peticiones HTTP recibidas del balanceador
- Sirven contenido estático (HTML, CSS, imágenes) desde NFS
- Delegan el procesamiento PHP al servidor NFS vía FastCGI
- Operan en configuración activo-activo

**Servidor NFS**:
- Comparte el directorio `/var/www/html` mediante protocolo NFS
- Ejecuta PHP-FPM en puerto 9000 para procesar código PHP
- Almacena el código fuente de la aplicación de forma centralizada

#### Capa 3 - Proxy de Base de Datos

**Función**: balanceo de carga y punto único de acceso a las bases de datos.

- Distribuye consultas SQL entre los nodos del cluster Galera
- Realiza health checks para verificar disponibilidad de cada nodo
- Proporciona un endpoint único (192.168.20.10:3306) para los servidores web
- Permite escalabilidad horizontal sin modificar configuración de aplicaciones

#### Capa 4 - Datos (Cluster MariaDB Galera)

**Función**: almacenamiento persistente y replicación de datos.

- Cluster de dos nodos con replicación síncrona multi-maestro
- Cada escritura se replica automáticamente a todos los nodos
- Garantiza consistencia de datos mediante Galera Cluster
- Permite lecturas y escrituras en cualquier nodo

### 2.4. Flujo de una Petición Completa

1. Usuario accede desde navegador a `http://localhost:8080`
2. Petición llega al **balanceador Nginx** (192.168.5.10)
3. Balanceador selecciona un servidor web mediante round-robin
4. **Servidor Web** (192.168.10.10 o 192.168.10.11) recibe la petición
5. Para archivos estáticos: servidor web los sirve desde montaje NFS
6. Para archivos PHP: servidor web envía petición a **PHP-FPM** (192.168.20.13:9000)
7. PHP-FPM ejecuta el código y realiza consultas SQL al **Proxy HAProxy** (192.168.20.10:3306)
8. HAProxy selecciona un nodo del **cluster Galera** (192.168.40.11 o 192.168.40.12)
9. MariaDB procesa la consulta y devuelve los datos
10. La respuesta recorre el camino inverso hasta el usuario

---

## 3. Direccionamiento IP Utilizado

### 3.1. Tabla Completa de Direccionamiento

| Hostname | Interfaz 1 | Red 1 | Interfaz 2 | Red 2 | Servicios | Puertos |
|----------|-----------|-------|-----------|-------|-----------|---------|
| **balanceadorManuelR** | 192.168.5.10 | Pública | 192.168.10.14 | Web | Nginx (balanceador) | 80 |
| **serverweb1ManuelR** | 192.168.10.10 | Web | 192.168.20.11 | NFS | Nginx (web) | 80 |
| **serverweb2ManuelR** | 192.168.10.11 | Web | 192.168.20.12 | NFS | Nginx (web) | 80 |
| **serverNFSManuelR** | 192.168.10.13 | Web | 192.168.20.13 | NFS | NFS, PHP-FPM | 2049, 9000 |
| **proxyDBManuelR** | 192.168.20.10 | NFS | 192.168.40.10 | Database | HAProxy | 3306, 8080 |
| **serverdatos1ManuelR** | 192.168.40.11 | Database | - | - | MariaDB Galera | 3306, 4567 |
| **serverdatos2ManuelR** | 192.168.40.12 | Database | - | - | MariaDB Galera | 3306, 4567 |

### 3.2. Puertos Utilizados

| Puerto | Protocolo | Servicio | Máquina |
|--------|-----------|----------|---------|
| 80 | HTTP | Balanceador Nginx | balanceadorManuelR |
| 80 | HTTP | Servidores Web | serverweb1ManuelR, serverweb2ManuelR |
| 2049 | NFS | Servidor de archivos | serverNFSManuelR |
| 9000 | FastCGI | PHP-FPM | serverNFSManuelR |
| 3306 | MySQL | Proxy HAProxy | proxyDBManuelR |
| 3306 | MySQL | MariaDB | serverdatos1ManuelR, serverdatos2ManuelR |
| 4567 | Galera | Replicación Cluster | serverdatos1ManuelR, serverdatos2ManuelR |
| 8080 | HTTP | Estadísticas HAProxy | proxyDBManuelR |

### 3.3. Port Forwarding

El único puerto expuesto al host Windows es:

- **Host**: `localhost:8080`
- **Guest**: `192.168.5.10:80` (balanceadorManuelR)

Esto permite acceder a la aplicación web desde el navegador del sistema anfitrión mediante `http://localhost:8080`

---

## 4. Máquinas Virtuales y Scripts de Aprovisionamiento
### 4.1. Balanceador de Carga
Nombre de la Máquina
balanceadorManuelR
Función Principal
Actúa como punto de entrada único para todo el tráfico HTTP externo. Distribuye las peticiones entre los servidores web backend mediante algoritmo round-robin, proporcionando alta disponibilidad y balanceo de carga.
Direcciones IP

Red Pública: 192.168.5.10
Red Web: 192.168.10.14

Servicios Instalados:
Nginx: servidor web configurado como balanceador de carga
Port Forwarding: puerto 80 mapeado al puerto 8080 del host

# Script de Aprovisionamiento
balanceador.sh
---

#!/bin/bash

# Script de aprovisionamiento del Balanceador de Carga Nginx
# Capa 1 - Expuesta a red pública

echo "=== Actualización del sistema ==="
apt-get update

echo "=== Instalación de Nginx ==="
apt-get install -y nginx

echo "=== Configurando Nginx como balanceador de carga ==="
cat > /etc/nginx/conf.d/load-balancer.conf <<'EOF'
upstream backend_servers {
    server 192.168.10.10:80;
    server 192.168.10.11:80;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Eliminar la configuración que viene por defecto
rm -f /etc/nginx/sites-enabled/default

echo "=== Habilitando y reiniciando Nginx ==="
systemctl enable nginx
systemctl restart nginx

echo "=== Configurando IP forwarding ==="
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "=== Balanceador configurado correctamente ==="

---


### 4.2. Servidor Web 1
Nombre de la Máquina
serverweb1ManuelR
Función Principal
Procesa peticiones HTTP recibidas del balanceador. Sirve contenido estático desde el montaje NFS y delega el procesamiento de archivos PHP al servidor NFS mediante FastCGI.
Direcciones IP

Red Web: 192.168.10.10
Red NFS: 192.168.20.11

Servicios Instalados:

Nginx: servidor web
NFS Client: cliente para montar sistemas de archivos remotos

Script de Aprovisionamiento
web1.sh
---

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

---

### 4.3. Servidor Web 2
Nombre de la Máquina
serverweb2ManuelR
Función Principal
Idéntica al Servidor Web 1. Proporciona redundancia y permite balanceo de carga entre múltiples servidores web.
Direcciones IP

Red Web: 192.168.10.11
Red NFS: 192.168.20.12
Servicios Instalados
Nginx: servidor web
NFS Client: cliente para montar sistemas de archivos remotos

Script de Aprovisionamiento
web2.sh

---

#!/bin/bash

# Script de aprovisionamiento del Servidor Web 2
# Capa 2 - Backend (Nginx + NFS)

echo "=== Actualizando sistema ==="
apt-get update

echo "=== Instalando Nginx y NFS client ==="
apt-get install -y nginx nfs-common

echo "=== Creando directorio para NFS ==="
mkdir -p /var/www/html

echo "=== Configurando montaje NFS ==="
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

echo "=== Servidor Web 2 configurado correctamente ==="

---

### 4.4. Servidor NFS
Nombre de la Máquina
serverNFSManuelR
Función Principal
Cumple una doble función crítica: almacenar y compartir los archivos de la aplicación mediante NFS, y ejecutar el motor PHP-FPM que procesa el código PHP de la aplicación.
Direcciones IP
Red Web: 192.168.10.13
Red NFS: 192.168.20.13
Servicios Instalados:

NFS Server: servidor de archivos en red
PHP-FPM: procesador FastCGI para PHP
Extensiones PHP: mysql, curl, gd, mbstring, xml, zip
Git: para clonar el repositorio de la aplicación

Script de Aprovisionamiento:
nfs.sh

---

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

---

### 4.5. Proxy de Base de Datos
Nombre de la Máquina
proxyDBManuelR
Función Principal
Actúa como balanceador de carga y punto único de acceso al cluster de bases de datos. Distribuye las consultas SQL entre los nodos Galera y realiza health checks automáticos.
Direcciones IP
Red NFS: 192.168.20.10
Red Database: 192.168.40.10
Servicios Instalados:

HAProxy: balanceador de carga para TCP
MariaDB Client: herramientas de línea de comandos para pruebas

Script de Aprovisionamiento
proxy.sh

---

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

---

### 4.6. Servidor de Datos 1
Nombre de la Máquina
serverdatos1ManuelR
Función Principal
Nodo primario del cluster MariaDB Galera. Inicializa el cluster, crea la base de datos, importa el esquema y replica todos los cambios al nodo secundario.
Dirección IP
Red Database: 192.168.40.11
Servicios Instalados:

MariaDB Server: sistema gestor de bases de datos
Galera Cluster: motor de replicación síncrona
Rsync: utilidad para sincronización de datos
Git: para descargar el esquema de la base de datos

Script de Aprovisionamiento
db1.sh

---

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

---

### 4.7. Servidor de Datos 2
Nombre de la Máquina
serverdatos2ManuelR
Función Principal
Nodo secundario del cluster MariaDB Galera. Se une al cluster existente y sincroniza automáticamente todos los datos desde el nodo primario.
Dirección IP

Red Database: 192.168.40.12

Servicios Instalados

MariaDB Server: sistema gestor de bases de datos
Galera Cluster: motor de replicación síncrona
Rsync: utilidad para sincronización de datos

Script de Aprovisionamiento
db2.sh

---


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

---

## 5. Estructura del Proyecto

```
infraestructura-lemp-ha/
├── Vagrantfile
├── README.md
├── balanceador.sh
├── web1.sh
├── web2.sh
├── nfs.sh
├── proxy.sh
├── db1.sh
└── db2.sh
```

### 5.2. Despliegue de la Infraestructura

**Tiempo total estimado**: 15-20 minutos dependiendo de la velocidad de Internet y CPU.

#### Comando (Levantamiento Simultáneo)

```bash
vagrant up serverdatos1ManuelR serverdatos2ManuelR proxyDBManuelR serverNFSManuelR serverweb1ManuelR serverweb2ManuelR balanceadorManuelR
```

Este comando levanta todas las máquinas simultáneamente, pero puede causar problemas de dependencias. El arranque secuencial es más seguro.

### 5.3. Verificación del Despliegue

#### Comprobar Estado de las Máquinas

```bash
vagrant status
```

**Salida esperada**:
```
Current machine states:

balanceadorManuelR        running (virtualbox)
serverweb1ManuelR         running (virtualbox)
serverweb2ManuelR         running (virtualbox)
serverNFSManuelR          running (virtualbox)
proxyDBManuelR            running (virtualbox)
serverdatos1ManuelR       running (virtualbox)
serverdatos2ManuelR       running (virtualbox)
```

Todas las máquinas deben estar en estado `running`.

### 5.4. Acceso a la Aplicación Web

1. Abrir navegador web (Chrome, Firefox, Edge)
2. Navegar a `http://localhost:8080`
3. Debería aparecer la aplicación de gestión de usuarios

---

## 6. Verificación del Sistema

### 6.1. Verificación de Conectividad entre Máquinas
