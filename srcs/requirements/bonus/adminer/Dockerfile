FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    php7.4-cli \
    php7.4-mysql \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html \
    && curl -L https://www.adminer.org/latest.php \
       -o /var/www/html/index.php

# COPY adminer.css /var/www/html/adminer.css
COPY tools/start.sh /usr/local/bin/start-adminer.sh

RUN chmod +x /usr/local/bin/start-adminer.sh

WORKDIR /var/www/html

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/start-adminer.sh"]