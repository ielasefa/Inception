#!/bin/sh

set -e

echo "Starting Adminer on port 8080..."

exec php -S 0.0.0.0:8080 -t /var/www/html