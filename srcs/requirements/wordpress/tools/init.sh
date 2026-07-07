#!/bin/bash

set -e

echo "Waiting for MariaDB to be ready..."
while ! mysqladmin ping -h mariadb -P 3306 --silent 2>/dev/null; do
    sleep 1
done
echo "MariaDB is up and running!"

cd /var/www/html

if [ ! -f "wp-config.php" ]; then
    echo "WordPress not found. Installing..."

    wp core download --allow-root --version=6.4 --locale=en_US

    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --path='/var/www/html'

    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}"

    wp user create "${WP_USER_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASS}" \
        --role=author \
        --allow-root

    echo "WordPress installation and user creation finished!"
fi

chown -R www-data:www-data /var/www/html

echo "Starting PHP-FPM..."

exec php-fpm7.4 -F