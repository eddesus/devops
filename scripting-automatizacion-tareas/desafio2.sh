#!/bin/bash
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Este script debe ejecutarse como root o con "
        exit 1
    fi
}

install_packages() {
    local packages=("apache2" "ghostscript" "libapache2-mod-php" "mysql-server" "php" "php-bcmath" "php-mysql" "php-gd" "php-xml" "php-mbstring" "php-intl" "php-curl" "php-imagick" "php-intl" "php-json" "php-zip")

    for package in "${packages[@]}"; do
        if ! dpkg -l "$package" > /dev/null 2>&1; then
            echo "El paquete $package no está instalado. Instalándolo ahora..."
            apt-get install -y "$package"
        else
            echo "El paquete $package ya está instalado."
        fi
    done
}

install_wordpress() {
    mkdir -p /srv/www
    systemctl stop apache2
    chown www-data: /srv/www
    curl https://wordpress.org/latest.tar.gz | tar zx -C /srv/www

    cat <<EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF
    a2ensite wordpress
    a2enmod rewrite

    a2dissite 000-default
    systemctl restart apache2
}


configure_database() {
    local DB_USER=wordpress
    local DB_PASSWORD=wordpress
    local DB_NAME=wordpress

    systemctl start mysql

    mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
}

configure_wordpress() {
    local DB_USER="wordpress"
    local DB_PASSWORD="wordpress"
    local DB_NAME="wordpress"
    local PHRASE=c893bad68927b457dbed39460e6afd62
    cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php

    sed -i "s/database_name_here/$DB_NAME/g" /srv/www/wordpress/wp-config.php
    sed -i "s/username_here/$DB_USER/g" /srv/www/wordpress/wp-config.php
    sed -i "s/password_here/$DB_PASSWORD/g" /srv/www/wordpress/wp-config.php
    sed -i "s@put your unique phrase here@$PHRASE@g" /srv/www/wordpress/wp-config.php
}   

check_root
install_packages
install_wordpress
configure_database
configure_wordpress