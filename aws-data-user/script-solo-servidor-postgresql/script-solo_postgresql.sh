#!/bin/bash

######## Verificar si el script esta siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ser ejecutado como root."
  exit 1  # Salir con un codigo de error
else
echo "Eres root. Ejecutando el comando..."


########Instalacion postgresql y sus dependencias
apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
apt install curl ca-certificates
install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
apt update
apt -y install postgresql-17


######### Configuracion PostgreSQL: crear usuario y base de datos para matrix
sudo -u postgres createuser --pwprompt synapse_user
sudo -u postgres createdb --encoding=UTF8 --locale=C --template=template0 --owner=synapse_user synapse
clear
echo "Se ha creado la base de datos y el usuario correctamente"


####### Configuracion PostgreSQL: Puertos de escucha
# Hacer una copia de seguridad del archivo pg_hba.conf y postgresql.conf
mv /etc/postgresql/17/main/pg_hba.conf /etc/postgresql/17/main/pg_hba.conf.back
cp /etc/postgresql/17/main/postgresql.conf /etc/postgresql/17/main/postgresql.conf.back

read -p "Pon la IP de red en la que están los servidores de Matrix" matrixip

#  Creacion de un nuevo archivo de configuracion pg_hba.conf
cat << EOF > /etc/postgresql/17/main/pg_hba.conf
# Database administrative login by Unix domain socket
local   all             postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer

# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256

# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256

# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
host  	all		          all		          10.0.1.0/24             md5	
host    all             all             10.0.2.0/24             md5
host    all             all             $matrixip/24             md5
EOF


# Descomentar la linea 'listen_addresses' en postgresql.conf
sed -i 's/^#\s*listen_addresses/listen_addresses/' /etc/postgresql/17/main/postgresql.conf
sed -i "s/^listen_addresses\s*=\s*'localhost'/listen_addresses = '0.0.0.0'/" "/etc/postgresql/17/main/postgresql.conf"


# Reiniciar el servicio de PostgreSQL para aplicar los cambios
systemctl restart postgresql
echo "PostgreSQL ha sido configurado correctamente y reiniciado."


######### Finalizamos el script
fi