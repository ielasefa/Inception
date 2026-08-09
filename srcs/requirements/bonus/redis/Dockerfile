FROM debian:bullseye

RUN apt-get update \
    && apt-get install -y --no-install-recommends redis-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data \
    && chown redis:redis /data

COPY conf/redis.conf /etc/redis/redis.conf
COPY tools/start.sh /usr/local/bin/start-redis.sh

RUN chmod +x /usr/local/bin/start-redis.sh

EXPOSE 6379

ENTRYPOINT ["/usr/local/bin/start-redis.sh"]