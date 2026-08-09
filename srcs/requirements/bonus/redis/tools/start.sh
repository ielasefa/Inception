#!/bin/sh

set -e

echo "Starting Redis..."

exec redis-server /etc/redis/redis.conf