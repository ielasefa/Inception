#!/bin/bash

set -eu

MYSQL_HOST="${MYSQL_HOST:-mariadb}"

echo "Waiting for MariaDB to be ready..."
while ! mysqladmin ping -h "${MYSQL_HOST}" -P 3306 --silent 2>/dev/null; do
    sleep 1
done
echo "MariaDB is up and running!"

cd /var/www/html

if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "WordPress not found. Installing..."

    if [ ! -f "wp-settings.php" ]; then
        wp core download --allow-root --version=6.4 --locale=en_US
    fi

    if [ ! -f "wp-config.php" ]; then
        wp config create --allow-root \
            --dbname="${MYSQL_DATABASE}" \
            --dbuser="${MYSQL_USER}" \
            --dbpass="${MYSQL_PASSWORD}" \
            --dbhost="${MYSQL_HOST}:3306" \
            --path="/var/www/html"
    fi

    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}"

    echo "WordPress installation finished!"
fi

if wp user get "${WP_USER_USER}" --allow-root >/dev/null 2>&1; then
    echo "WordPress user already exists."
elif wp user get "${WP_USER_EMAIL}" --allow-root >/dev/null 2>&1; then
    echo "WordPress user email already exists; skipping user creation."
else
    wp user create "${WP_USER_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASS}" \
        --role=author \
        --allow-root
fi

chown -R www-data:www-data /var/www/html

echo "Starting PHP-FPM..."

exec "$@"
