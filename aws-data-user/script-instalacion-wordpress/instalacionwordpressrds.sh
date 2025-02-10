#variables
DB_NAME="wordpress"
DB_USER="wordpress"
DB_PASSWORD="Admin123"
DB_HOST="ec2-reto-mysqlrds-acqpbtihi3zu.cfulp7cf58bw.us-east-1.rds.amazonaws.com" #Poner el punto de enlace del rds
WP_URL="http://borjaticket.duckdns.org/" #Cambiar a tu dominio
WP_TITLE="Mi WordPress"
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD="Admin123"
WP_ADMIN_EMAIL="admin@example.com"
WP_DIR="/var/www/html/wordpress"
DUCKDNS_DIR="$HOME/duckdns"
DUCKDNS_SCRIPT="$DUCKDNS_DIR/duck.sh"
LOG_FILE="$DUCKDNS_DIR/duck.log"
TOKEN="4dbddd47-3973-4459-9590-544505b5c461" #Cambiar
DOMAIN="borjaticket" #Cambiar
# Actualizamos paquetes e instalamos dependencias
echo "🔄 Instalando Apache, MySQL y PHP..."
apt update
apt install -y apache2 mysql-server mysql-client php libapache2-mod-php php-mysql wget unzip curl php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-ftp
# Iniciamos y habilitamos Apache y MySQL
echo "🚀 Habilitando Apache"
echo "Habilitando mysql"
systemctl enable --now apache2
systemctl enable --now mysql
# Configuramos la base de datos MySQL
echo "🛠️ Configurando MySQL..."
mysql -u root -e "CREATE DATABASE $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"
# Descargamos y configuramos WordPress
echo "📥 Descargando WordPress..."
cd /var/www/html
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress $WP_DIR
rm -f latest.tar.gz
# Configuramos wp-config.php
echo "📝 Configurando WordPress..."
cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" $WP_DIR/wp-config.php
sed -i "s/username_here/$DB_USER/" $WP_DIR/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" $WP_DIR/wp-config.php
sed -i "s/localhost/$DB_HOST/" $WP_DIR/wp-config.php

echo "define('FS_METHOD', 'direct');" >> $WP_DIR/wp-config.php
echo "define('WP_SITEURL', 'http://borjaticket.duckdns.org');" >> $WP_DIR/wp-config.php #Cambiar por tu dominio
echo "define('WP_HOME', 'http://borjaticket.duckdns.org');" >> $WP_DIR/wp-config.php #Cambiar por tu dominio
#wp option update home 'http://borjaticket.duckdns.org' #cambiar por tu dominio
#wp option update siteurl 'http://borjaticket.duckdns.org' #cambiar por tu dominio
# Configuración de permisos
echo "🔑 Configurando permisos..."
chown -R www-data:www-data $WP_DIR
find $WP_DIR -type d -exec chmod 755 {} \;
find $WP_DIR -type f -exec chmod 644 {} \;
# Habilitamos mod_rewrite en Apache
echo "🌐 Configurando Apache..."
a2enmod rewrite
sed -i 's|DocumentRoot .*|DocumentRoot /var/www/html/wordpress|' /etc/apache2/sites-available/000-default.conf
systemctl restart apache2
# Instalamos WP-CLI si no está presente
if ! command -v wp &> /dev/null; then
    echo "🛠️ Instalando WP-CLI..."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
fi
# Instalación automática de WordPress
echo "🚀 Instalando WordPress automáticamente..."
sudo -u www-data wp core install --path=$WP_DIR --url="$WP_URL" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email
# Instalamos idioma en español
echo "🌍 Instalando idioma español..."
sudo -u www-data wp core language install es_ES --path=$WP_DIR
sudo -u www-data wp site switch-language es_ES --path=$WP_DIR
# Instalamos y activamos el plugin SupportCandy
echo "📦 Instalando SupportCandy..."
sudo -u www-data wp plugin install supportcandy --activate --path=$WP_DIR
#Instalamos y activamos el plugin Ultimate-member
echo "Instalando Ultimate-Member"
sudo -u www-data wp plugin install ultimate-member --activate --path=$WP_DIR
# Crear directorio si no existe
mkdir -p "$DUCKDNS_DIR"
# Crear script de actualización de IP
echo "echo url=\"https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=\" | curl -k -o $LOG_FILE -K -" > "$DUCKDNS_SCRIPT"
echo "🛠️ Configurando MySQL..."
# Dar permisos de ejecución
chmod 700 "$DUCKDNS_SCRIPT"
# Añadir tarea a crontab si no existe
(crontab -l | grep -q "$DUCKDNS_SCRIPT") || (crontab -l 2>/dev/null; echo "*/5 * * * * $DUCKDNS_SCRIPT >/dev/null 2>&1") | crontab -
# Ejecutar el script manualmente para probar
"$DUCKDNS_SCRIPT"
# Verificar si la actualización fue exitosa
sleep 2
cat "$LOG_FILE"
cd /var/www/html/wordpress
wp option update home 'http://borjaticket.duckdns.org' --allow-root #cambiar por tu dominio
wp option update siteurl 'http://borjaticket.duckdns.org' --allow-root #cambiar por tu dominio
# Confirmación final
echo "✅ WordPress ha sido instalado automáticamente en $WP_URL"
echo "🌍 Idioma configurado en Español"
echo "🔑 Usuario Admin: $WP_ADMIN_USER"
echo "🔑 Contraseña: $WP_ADMIN_PASSWORD"





