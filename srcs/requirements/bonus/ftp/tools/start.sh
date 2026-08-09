#!/bin/sh

set -e

FTP_USER="${FTP_USER:-ftpuser}"
FTP_PASSWORD="${FTP_PASSWORD:-ftp123}"

if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd -m -d /var/www/html -s /bin/bash "$FTP_USER"
fi

echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd

chown -R "$FTP_USER":"$FTP_USER" /var/www/html

echo "Starting FTP server..."

exec /usr/sbin/vsftpd /etc/vsftpd.conf