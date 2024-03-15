#!/bin/bash

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Este script debe ejecutarse como root o con sudo."
        exit 1
    fi
}

install_packages() {
    apt update
    local packages=("apache2" "mysql-server" "php" "php-mysql" "php-gd" "php-xml" "php-mbstring" "php-intl")

    for package in "${packages[@]}"; do
        if ! dpkg -l "$package" > /dev/null 2>&1; then
            echo "El paquete $package no está instalado. Instalándolo ahora..."
            apt-get install -y "$package"
        else
            echo "El paquete $package ya está instalado."
        fi
    done
}

setup_mysql_security() {
    local DB_USER="phpmyadmin"
    local DB_PASSWORD="phpmyadmin"
    mysql -u root <<MYSQL_SCRIPT
    CREATE USER '$DB_USER'@'localhost' IDENTIFIED with caching_sha2_password BY '$DB_PASSWORD';
    GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    echo 'Mysql security done'
}

install_myphpmyadmin() {
    export DEBIAN_FRONTEND="noninteractive"
    local MYSQL_PHPMYADMIN_PASSWORD=phpmyadmin
    apt update
    apt install -yq phpmyadmin

    # Set the MySQL administrative user's password
    debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
    debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-user string phpmyadmin"
    debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_PHPMYADMIN_PASSWORD"
    debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_PHPMYADMIN_PASSWORD"
    debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"

    dpkg-reconfigure -f noninteractive phpmyadmin

    echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf

    service apache2 restart
    echo "Apache service restarted"
}

secure_phpmyadmin() {
    sed -i '/index.php/ a AllowOverride All' /etc/apache2/conf-available/phpmyadmin.conf
    systemctl restart apache2

    cat << EOF >> /usr/share/phpmyadmin/.htaccess
AuthType Basic
AuthName "Restricted Access"
AuthUserFile /etc/phpmyadmin/.htpasswd
Require valid-user 
EOF
    
    htpasswd -b -c /etc/phpmyadmin/.htpasswd adminmysql p4ssw0rd

    sed -i "0,/phpmyadmin/s/phpmyadmin/securemyadmin/" /etc/apache2/conf-available/phpmyadmin.conf

    systemctl reload apache2
}

check_root
install_packages
setup_mysql_security
install_myphpmyadmin
secure_phpmyadmin
