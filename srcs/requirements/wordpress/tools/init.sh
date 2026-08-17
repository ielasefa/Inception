#!/bin/bash

set -eu

MYSQL_HOST="${MYSQL_HOST:-mariadb}"
MYSQL_RETRIES="${MYSQL_RETRIES:-60}"
WP_SITE_URL="${WP_URL:-https://${DOMAIN_NAME}}"
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"

echo "Waiting for MariaDB to be ready..."

attempt=0
until mariadb \
    -h "${MYSQL_HOST}" \
    -P 3306 \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    "${MYSQL_DATABASE}" \
    -e "SELECT 1;" >/dev/null 2>&1
do
    attempt=$((attempt + 1))

    if [ "${attempt}" -ge "${MYSQL_RETRIES}" ]; then
        echo "MariaDB did not become ready after ${MYSQL_RETRIES} attempts." >&2
        exit 1
    fi

    echo "MariaDB is not ready yet..."
    sleep 2
done

echo "MariaDB is up and authentication succeeded!"

cd /var/www/html

if [ ! -f "wp-settings.php" ]; then
    echo "Downloading WordPress..."

    wp core download \
        --allow-root \
        --version=6.4 \
        --locale=en_US
fi

if [ ! -f "wp-config.php" ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${MYSQL_HOST}:3306" \
        --path="/var/www/html"
else
    echo "Updating database configuration..."

    wp config set DB_NAME "${MYSQL_DATABASE}" \
        --type=constant --allow-root

    wp config set DB_USER "${MYSQL_USER}" \
        --type=constant --allow-root

    wp config set DB_PASSWORD "${MYSQL_PASSWORD}" \
        --type=constant --allow-root

    wp config set DB_HOST "${MYSQL_HOST}:3306" \
        --type=constant --allow-root
fi

wp config set WP_REDIS_HOST "${REDIS_HOST}" \
    --type=constant --allow-root

wp config set WP_REDIS_PORT "${REDIS_PORT}" \
    --type=constant --raw --allow-root

if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --url="${WP_SITE_URL}" \
        --title="${WP_TITLE:-Inception}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email

    echo "WordPress installation finished!"
else
    echo "WordPress is already installed."
fi

if wp user get "${WP_USER_USER}" --allow-root >/dev/null 2>&1; then
    echo "WordPress user already exists."
elif wp user get "${WP_USER_EMAIL}" --allow-root >/dev/null 2>&1; then
    echo "WordPress email already exists."
else
    echo "Creating WordPress author..."

    wp user create \
        "${WP_USER_USER}" \
        "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASS}" \
        --role=author \
        --allow-root
fi

if ! wp plugin is-installed redis-cache --allow-root; then
    wp plugin install redis-cache --activate --allow-root
elif ! wp plugin is-active redis-cache --allow-root; then
    wp plugin activate redis-cache --allow-root
fi

wp redis enable --allow-root

chown -R www-data:www-data /var/www/html

echo "Starting PHP-FPM..."

exec "$@"
