#!/bin/bash

# Add PostgreSQL APT repository
sudo apt install wget -y
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee -a /etc/apt/trusted.gpg.d/pgdg.asc
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update -y
sudo apt install postgresql-17 -y
sudo apt-get install postgresql-client
clear

# Variable matrix
echo "Paso 1"
read -p "Escribe la red en la que esta el servidor de comunicaciones 'ej: 192.168.100.1/24': " RED
clear


# Variables configurables
REPMGR_DB="repmgr"
REPMGR_USER="repmgr"
PRIMARY_IP="10.215.3.100"   # IP del servidor maestro
NODE_NAME="pg1"
DATA_DIR="/var/lib/postgresql/17/main"
REPMGR_CONF="/etc/repmgr.conf"
POSTGRES_VERSION="17"           # Cambia esto si tienes una versión diferente
SYNAPSE_USER="synapse_user"
DB_SYNAPSE="synapse"

# Función para ejecutar como usuario postgres
exec_as_postgres() {
    sudo -u postgres bash -c "$1"
}

# Actualizar y instalar PostgreSQL y repmgr
echo "Instalando PostgreSQL y repmgr..."
sudo apt update
sudo apt install -y postgresql-17-repmgr
sudo systemctl enable postgresql
clear

# Asignar contraseña al usuario postgres
echo "Asignando contraseña al usuario postgres..."
sudo passwd postgres
clear



read  -p "Entra a tu otra maquina donde quieres tener el sevidor esclavo y ejecuta el script de instalacion, cuando en la otrs maquina te salga que ya puedes regresar, haz click en enter"
echo "¡Has presionado Enter! Continuando con el script..."



# Configurar claves SSH para replicación
#echo "Generando claves SSH para replicación..."
#exec_as_postgres "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
#exec_as_postgres "ssh-copy-id postgres@$STANDBY_IP"
#clear


# Crear usuario y base de datos repmgr
echo "Creando usuario y base de datos repmgr..."
exec_as_postgres "createuser -s $REPMGR_USER"
exec_as_postgres "createdb $REPMGR_DB -O $REPMGR_USER"
exec_as_postgres "createuser --pwprompt $SYNAPSE_USER"
exec_as_postgres "createdb --encoding=UTF8 --locale=C --template=template0 --owner=synapse_user $DB_SYNAPSE"



# Modificar postgresql.conf
echo "Configurando postgresql.conf..."
#sudo sed -i "/^#shared_preload_libraries/c\shared_preload_libraries = 'repmgr'" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#wal_level/c\wal_level = replica" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#archive_mode/c\archive_mode = on" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#archive_command/c\archive_command = '/bin/true'" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#max_wal_senders/c\max_wal_senders = 10" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#max_replication_slots/c\max_replication_slots = 10" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#hot_standby/c\hot_standby = on" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#listen_addresses/c\listen_addresses = '*'" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
sudo sed -i "/^#wal_log_hints/c\wal_log_hints = on" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf

# Configurar pg_hba.conf
echo "Configurando pg_hba.conf..."
PG_HBA_PATH="/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf"
sudo bash -c "cat >> $PG_HBA_PATH" <<EOF
# Configuración para repmgr y replicación
local   replication   $REPMGR_USER                                   trust
host    replication   $REPMGR_USER     127.0.0.1/32                  trust
local   $REPMGR_DB    $REPMGR_USER                                   trust
host    $REPMGR_DB    $REPMGR_USER     127.0.0.1/32                  trust
host    all             all             $RED             md5
EOF

#host    replication   $REPMGR_USER     $PRIMARY_IP/32                trust
#host    replication   $REPMGR_USER     $STANDBY_IP/32                trust
#host    $REPMGR_DB    $REPMGR_USER     $PRIMARY_IP/32                trust
#host    $REPMGR_DB    $REPMGR_USER     $STANDBY_IP/32                trust

# Reiniciar servicio PostgreSQL
echo "Reiniciando servicio PostgreSQL..."
sudo systemctl restart postgresql

# Crear archivo de configuración de repmgr
#echo "Creando archivo de configuración de repmgr en $REPMGR_CONF..."
#sudo bash -c "cat > $REPMGR_CONF" <<EOF
#node_id=1
#node_name=$NODE_NAME
#conninfo='host=$PRIMARY_IP user=$REPMGR_USER dbname=$REPMGR_DB connect_timeout=2'
#data_directory='$DATA_DIR'
#failover=automatic
#promote_command='repmgr -f $REPMGR_CONF standby promote --log-to-file'
#follow_command='repmgr -f $REPMGR_CONF standby follow --log-to-file'
#log_file='/var/log/postgresql/repmgr.log'
#use_replication_slots=1  # Usar replication slots
#EOF

# Registrar el servidor principal en repmgr
#echo "Registrando el servidor principal en repmgr..."
#exec_as_postgres "repmgr -f $REPMGR_CONF primary register"
#exec_as_postgres "repmgr -f $REPMGR_CONF cluster show"

# Iniciar repmgrd (daemon)
#echo "Iniciando el daemon de repmgr..."
#exec_as_postgres "repmgrd -f $REPMGR_CONF -d"

#echo "¡Configuración de PostgreSQL con repmgr en el servidor maestro completada!"
