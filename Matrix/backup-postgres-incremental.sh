#!/bin/bash

######## Verificar si el script está siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ser ejecutado como root."
    exit 1  # Salir con un código de error
else
    echo "Eres root. Ejecutando el comando..."

    # Actualiza la lista de paquetes
    apt update

    # Verifica si rsync está instalado
    if ! command -v rsync &> /dev/null; then
        apt install -y rsync
    fi

    # Verifica si AWS CLI está instalado
    if ! command -v aws &> /dev/null; then
        apt install -y awscli
    fi

    # Añadir configuraciones a postgresql.conf si no existen
    PG_CONF="/etc/postgresql/postgresql.conf"
    grep -qxF "wal_level = archive" "$PG_CONF" || echo "wal_level = archive" >> "$PG_CONF"
    grep -qxF "archive_mode = on" "$PG_CONF" || echo "archive_mode = on" >> "$PG_CONF"
    grep -qxF "archive_command = 'test ! -f /home/ubuntu/wal/%f && cp %p /home/ubuntu/wal/%f'" "$PG_CONF" || echo "archive_command = 'test ! -f /home/ubuntu/wal/%f && cp %p /home/ubuntu/wal/%f'" >> "$PG_CONF"

    # Crear directorio WAL y configurar permisos
    mkdir -p /home/ubuntu/wal
    chown postgres:postgres /home/ubuntu/wal
    chmod 700 /home/ubuntu/wal

    # Añadir configuraciones a pg_hba.conf
    PG_HBA="/etc/postgresql/17/main/pg_hba.conf"
    grep -qxF "hostssl replication synapse_user 10.210.3.100/32 md5" "$PG_HBA" || echo "hostssl replication synapse_user 10.210.3.100/32 md5" >> "$PG_HBA"
    grep -qxF "host replication synapse_user 10.210.3.100/32 md5" "$PG_HBA" || echo "host replication synapse_user 10.210.3.100/32 md5" >> "$PG_HBA"

    # Reiniciar PostgreSQL para aplicar los cambios
    systemctl restart postgresql

    # Otorgar el atributo REPLICATION a synapse_user
    sudo -u postgres psql -c "ALTER USER synapse_user WITH REPLICATION;"

    # Crea el archivo de script de respaldo
    cat <<EOF > /home/ubuntu/backup-postgres.sh
#!/bin/bash

# Especificar la ubicación del archivo de credenciales de AWS
export AWS_SHARED_CREDENTIALS_FILE="/home/ubuntu/.aws/credentials"

# Variables
BACKUP_DIR="/home/ubuntu/backups"
WAL_DIR="/home/ubuntu/wal"
DATE=\$(date +%Y-%m-%d)
S3_BUCKET="s3://s3-mensagl-marcos"
LOG_FILE="/var/log/backup-postgres.log"

# Crear directorio de backups si no existe
mkdir -p "\${BACKUP_DIR}"

# Realizar respaldo incremental de la base de datos synapse
export PGPASSWORD='Admin123'
pg_basebackup -h 10.210.3.100 -U synapse_user -D "\${BACKUP_DIR}/base_\${DATE}" -Ft -z -X fetch -P || { echo "Error al realizar el backup de PostgreSQL" >> "\${LOG_FILE}"; exit 1; }

# Copiar archivos WAL archivados
rsync -av --delete "\${WAL_DIR}/" "\${BACKUP_DIR}/wal_\${DATE}" || { echo "Error en rsync" >> "\${LOG_FILE}"; exit 1; }

# Comprimir el directorio de respaldo completo y los WAL archivados
tar -czf "\${BACKUP_DIR}/backup_full_\${DATE}.tar.gz" -C "\${BACKUP_DIR}" "base_\${DATE}" "wal_\${DATE}" || { echo "Error al comprimir" >> "\${LOG_FILE}"; exit 1; }

# Transferir la copia de seguridad a S3
aws s3 cp "\${BACKUP_DIR}/backup_full_\${DATE}.tar.gz" "\${S3_BUCKET}/backup_full_\${DATE}.tar.gz" || { echo "Error al subir a S3" >> "\${LOG_FILE}"; exit 1; }

EOF

    # Asegura que el archivo de backup sea ejecutable
    chmod +x /home/ubuntu/backup-postgres.sh
    
    # Configura la tarea cron para ejecutar el backup a las 2:00 AM todos los días
    tarea="0 2 * * * /home/ubuntu/backup-postgres.sh >> /var/log/backup-postgres.log 2>&1"

    # Añade la tarea cron al crontab actual, sin duplicar
    (crontab -l 2>/dev/null | grep -v -F "$tarea"; echo "$tarea") | crontab -
fi


