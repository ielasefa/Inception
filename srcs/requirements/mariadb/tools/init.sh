#!/bin/bash
set -e

chown -R mysql:mysql /var/lib/mysql

if [ ! -f "/var/lib/mysql/.initialized" ]; then
    echo "Initializing MariaDB..."
    
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        mysql_install_db --user=mysql --datadir=/var/lib/mysql
    fi

    mysqld --user=mysql &
    pid=$!
    
    while ! mysqladmin ping -h localhost --silent 2>/dev/null; do sleep 1; done

    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    touch /var/lib/mysql/.initialized
    echo "MariaDB initialized."
    
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
fi

exec mysqld --user=mysql