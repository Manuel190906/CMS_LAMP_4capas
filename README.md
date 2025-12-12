# CMS_LAMP_4capas
Instalación de CMS en arquitectura de 4 capas en alta disponibilidad.

# 📘 Documentación Técnica - Infraestructura LEMP en Alta Disponibilidad

## 📑 Índice

1. [Introducción del Proyecto](#1-introducción-del-proyecto)
2. [Arquitectura de la Infraestructura](#2-arquitectura-de-la-infraestructura)
3. [Direccionamiento IP Utilizado](#3-direccionamiento-ip-utilizado)
4. [Scripts de Aprovisionamiento](#4-scripts-de-aprovisionamiento)
   - 4.1. [Balanceador de Carga Nginx](#41-balanceador-de-carga-nginx)
   - 4.2. [Servidores Web (Web1 y Web2)](#42-servidores-web-web1-y-web2)
   - 4.3. [Servidor NFS con PHP-FPM](#43-servidor-nfs-con-php-fpm)
   - 4.4. [Proxy de Base de Datos HAProxy](#44-proxy-de-base-de-datos-haproxy)
   - 4.5. [Servidores de Base de Datos MariaDB Galera](#45-servidores-de-base-de-datos-mariadb-galera)
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

### 5.3. Estructura del Proyecto

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

### 5.4. Despliegue de la Infraestructura

**Tiempo total estimado**: 15-20 minutos dependiendo de la velocidad de Internet y CPU.

#### Comando (Levantamiento Simultáneo)

```bash
vagrant up serverdatos1ManuelR serverdatos2ManuelR proxyDBManuelR serverNFSManuelR serverweb1ManuelR serverweb2ManuelR balanceadorManuelR
```

Este comando levanta todas las máquinas simultáneamente, pero puede causar problemas de dependencias. El arranque secuencial es más seguro.

### 5.5. Verificación del Despliegue

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

### 5.6. Acceso a la Aplicación Web

1. Abrir navegador web (Chrome, Firefox, Edge)
2. Navegar a `http://localhost:8080`
3. Debería aparecer la aplicación de gestión de usuarios

---

## 6. Verificación del Sistema

### 6.1. Verificación de Conectividad entre Máquinas
