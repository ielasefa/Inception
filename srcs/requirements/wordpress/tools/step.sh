#!/bin/bash

# Exit immediately if any command fails
set -e

# Check if WordPress is already configured
if [ ! -f /var/www/html/wp-config.php ]; then

    # Go to the WordPress directory
    cd /var/www/html

    # Download the latest version of WordPress
    curl -O https://wordpress.org/latest.tar.gz

    # Extract the archive
    tar -xzf latest.tar.gz

    # Move WordPress files to the current directory
    mv wordpress/* .

    # Remove unnecessary files
    rm -rf wordpress latest.tar.gz

    # Create the WordPress configuration file
    wp config create \
        --allow-root \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$DB_HOST"

    # Install WordPress
    wp core install \
        --allow-root \
        --url="$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL"

    # Create an additional user
    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --allow-root
fi

# Start PHP-FPM in the foreground
exec /usr/sbin/php-fpm7.4 -F