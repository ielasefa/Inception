#!/bin/sh

set -e

FTP_USER="${FTP_USER:-ftpuser}"
FTP_PASSWORD="${FTP_PASSWORD:-ftp123}"

install -d -m 0555 -o root -g root /var/run/vsftpd/empty

if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd -M -d /var/www/html -s /bin/bash -g www-data "$FTP_USER"
else
    usermod -d /var/www/html -a -G www-data "$FTP_USER"
fi

echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd

chown -R www-data:www-data /var/www/html
chmod -R g+rwX /var/www/html

echo "Starting FTP server..."

exec /usr/sbin/vsftpd /etc/vsftpd.conf
