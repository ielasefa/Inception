#!/bin/bash

set -e

echo "Checking MariaDB directory permissions..."
chown -R mysql:mysql /var/lib/mysql

if [ ! -f "/var/lib/mysql/.initialized" ]; then
    echo "Initializing MariaDB for the first time..."
    
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    fi

    mariadbd --user=mysql --skip-networking &
    pid=$!
    
    echo "Waiting for MariaDB daemon to start..."
    while ! mariadb-admin ping -h localhost --silent 2>/dev/null; do 
        sleep 1
    done

    echo "Creating database and users..."
    mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    touch /var/lib/mysql/.initialized
    echo "MariaDB initialization finished successfully."
    
    mariadb-admin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait $pid 2>/dev/null || true
fi

echo "Starting MariaDB in foreground (PID 1)..."

exec mariadbd --user=mysql