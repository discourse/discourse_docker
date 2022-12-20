#!/bin/bash
set -e

# version check: https://redis.io/
REDIS_VERSION=6.2.6
REDIS_HASH="5b2b8b7a50111ef395bf1c1d5be11e6e167ac018125055daa8b5c2317ae131ab"

cd /tmp
# Prepare Redis source.
wget -q http://download.redis.io/releases/redis-$REDIS_VERSION.tar.gz
sha256sum redis-$REDIS_VERSION.tar.gz
echo "$REDIS_HASH redis-$REDIS_VERSION.tar.gz" | sha256sum -c

tar zxf redis-$REDIS_VERSION.tar.gz
cd redis-$REDIS_VERSION

# Building and installing binaries.
make BUILD_TLS=yes && make install PREFIX=/usr

# Add `redis` user and group.
adduser --system --home /var/lib/redis --quiet --group redis || true

# Configure Redis.
mkdir -p /etc/redis
mkdir -p /var/lib/redis
mkdir -p /var/log/redis
cp /tmp/redis-$REDIS_VERSION/redis.conf /etc/redis

chown -R redis:redis /var/lib/redis
chmod 750 /var/lib/redis

chown -R redis:redis /var/log/redis
chmod 750 /var/log/redis

# Clean up.
cd / && rm -rf /tmp/redis*
