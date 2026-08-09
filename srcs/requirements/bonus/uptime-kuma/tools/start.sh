#!/bin/sh

set -e

cd /app

echo "Starting Uptime Kuma..."

exec node server/server.js 