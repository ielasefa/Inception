FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld

COPY conf/50-server.conf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]