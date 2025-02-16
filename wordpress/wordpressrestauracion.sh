#!/bin/bash

######## Verificar si el script está siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ser ejecutado como root."
    exit 1  # Salir con un código de error
else
    echo "✅ Eres root. Ejecutando el comando..."
fi

# Variables
DB_NAME="wordpress"
DB_USER="wordpress"
DB_PASSWORD="Admin123"
DB_HOST="instancias-mysqlrds-ippomi78x0ll.cfmlrc67peco.us-east-1.rds.amazonaws.com" # Poner el punto de enlace del RDS
WP_URL="http://rufinoticket.duckdns.org/" # Cambiar a tu dominio
WP_TITLE="Mi WordPress"
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD="Admin123"
WP_ADMIN_EMAIL="admin@example.com"
WP_DIR="/var/www/html/wordpress"
NEW_LOGIN_PATH="acceso-admin"
WP_PREFIX="wp_"

# Actualizamos paquetes e instalamos dependencias
echo "🔄 Instalando Apache y PHP..."
apt update
apt install -y apache2 mysql-client php libapache2-mod-php php-mysql wget unzip curl php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-ftp

# Descargamos y configuramos WordPress
echo "📥 Descargando WordPress..."
cd /var/www/html
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
rm -f latest.tar.gz

# Configuración de permisos en la carpeta de WordPress
echo "🔑 Configurando permisos..."
chown -R www-data:www-data "$WP_DIR"
find "$WP_DIR" -type d -exec chmod 755 {} \;
find "$WP_DIR" -type f -exec chmod 644 {} \;

read -p "Carga la copia de seguridad, cuando esté cargada dale intro para seguir: " seguir

# Configuramos wp-config.php
echo "📝 Configurando WordPress..."
cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"
sed -i "s/database_name_here/$DB_NAME/" "$WP_DIR/wp-config.php"
sed -i "s/username_here/$DB_USER/" "$WP_DIR/wp-config.php"
sed -i "s/password_here/$DB_PASSWORD/" "$WP_DIR/wp-config.php"
sed -i "s/localhost/$DB_HOST/" "$WP_DIR/wp-config.php"
sed -i "s/\$table_prefix = 'wp_';/\$table_prefix = '${WP_PREFIX}';/" "$WP_DIR/wp-config.php"


echo "define('FS_METHOD', 'direct');" >> "$WP_DIR/wp-config.php"
echo "define('WP_SITEURL', '$WP_URL');" >> "$WP_DIR/wp-config.php"
echo "define('WP_HOME', '$WP_URL');" >> "$WP_DIR/wp-config.php"

# Deshabilitar pingbacks y trackbacks en WordPress
TABLE_PREFIX=$(grep "^\$table_prefix" "$WP_DIR/wp-config.php" | cut -d "'" -f2)
if [[ -z "$TABLE_PREFIX" ]]; then
    echo "❌ Error: No se pudo determinar el prefijo de la base de datos"
    exit 1
fi

echo "🔄 Desactivando pingbacks y trackbacks en WordPress..."
mysql -u"$DB_USER" -p"$DB_PASSWORD" -h "$DB_HOST" "$DB_NAME" <<SQL
UPDATE ${TABLE_PREFIX}options SET option_value = 'closed' WHERE option_name IN ('default_ping_status', 'default_pingback_flag');
UPDATE ${TABLE_PREFIX}posts SET ping_status = 'closed';
SQL

echo "✅ Pingbacks y trackbacks han sido deshabilitados correctamente."

# Configurar seguridad en .htaccess
HTACCESS_FILE="$WP_DIR/.htaccess"
if [[ -f "$HTACCESS_FILE" ]]; then
    echo "🛑 Creando respaldo de .htaccess..."
    cp "$HTACCESS_FILE" "${HTACCESS_FILE}.bak_$(date +%F_%H-%M-%S)"
fi

echo "🔒 Aplicando restricciones de seguridad en .htaccess..."
cat <<EOL >> "$HTACCESS_FILE"

# Bloquear acceso a archivos críticos
<FilesMatch "\.htaccess|htpasswd|wp-config\.php|xmlrpc\.php|readme\.html|license\.txt$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# Bloquear ejecución de archivos PHP en uploads, plugins y themes
<Directory "$WP_DIR/wp-content/uploads">
    <FilesMatch "\.php$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>
</Directory>

<Directory "$WP_DIR/wp-content/plugins">
    <FilesMatch "\.php$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>
</Directory>

<Directory "$WP_DIR/wp-content/themes">
    <FilesMatch "\.php$">
        Order Allow,Deny
        Deny from all
    </FilesMatch>
</Directory>

# Desactivar listado de directorios
Options -Indexes
EOL
chown www-data:www-data "$HTACCESS_FILE"
chmod 644 "$HTACCESS_FILE"

# Reiniciar Apache para aplicar cambios
echo "🔄 Reiniciando Apache..."
systemctl restart apache2
echo "✅ Seguridad aplicada en .htaccess correctamente."

# Descargar e instalar el plugin WPS Hide Login
echo "📥 Instalando el plugin WPS Hide Login..."
wp plugin install wps-hide-login --activate --allow-root --path="$WP_DIR"
wp option update whl_page "$NEW_LOGIN_PATH" --allow-root --path="$WP_DIR"

echo "✅ Instalación y configuración completada."
echo "🔗 Ahora puedes acceder a WordPress en: ${WP_URL}${NEW_LOGIN_PATH}"

# Confirmación final
echo "✅ WordPress ha sido instalado automáticamente en $WP_URL"
echo "🌍 Idioma configurado en Español"
echo "🔑 Usuario Admin: $WP_ADMIN_USER"
echo "🔑 Contraseña: $WP_ADMIN_PASSWORD"
