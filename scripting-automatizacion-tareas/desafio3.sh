#!/bin/bash

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Este script debe ejecutarse como root o con sudo."
        exit 1
    fi
}

install_node() {
    curl -s https://deb.nodesource.com/setup_16.x | bash
    apt-get install -y nodejs
}

clone_repo() {
    git clone https://gitlab.com/training-devops-cf/book-store-devops
    cd book-store-devops/book-store/

    npm install
}

install_pm2() {
    npm install pm2 -g

    cd book-store-devops/book-store/

    pm2 start --name book-store npm -- start

    pm2 startup

    pm2 save

}

inverse_proxy_ngnix() {
    apt update
    apt install nginx -y

    mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

     cat << EOF >> /etc/nginx/sites-available/default
    server {
        listen 80;
        #listen 443 ssl;
        server_name _;

        #ssl_certificate  /etc/nginx/ssl/server.crt;
        #ssl_certificate_key /etc/nginx/ssl/server.pem;

        location / {
                 proxy_pass http://localhost:3000;
                 proxy_http_version 1.1;
                 proxy_set_header Upgrade \$http_upgrade;
                 proxy_set_header Connection 'upgrade';
                 proxy_set_header Host \$host;
                 proxy_cache_bypass \$http_upgrade;
        }
} 
EOF
    systemctl restart nginx

}

check_root
install_node
clone_repo
install_pm2