FROM debian:bullseye

ARG DOMAIN_NAME=localhost

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx openssl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/ssl/private /etc/ssl/certs \
    && openssl req \
        -x509 \
        -nodes \
        -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/ssl/private/server.key \
        -out /etc/ssl/certs/server.crt \
        -subj "/CN=${DOMAIN_NAME}" \
        -addext "subjectAltName=DNS:${DOMAIN_NAME},DNS:localhost,IP:127.0.0.1" \
    && chmod 600 /etc/ssl/private/server.key \
    && chmod 644 /etc/ssl/certs/server.crt

COPY conf/default.conf /etc/nginx/nginx.conf
RUN sed -i "s/DOMAIN_NAME_PLACEHOLDER/${DOMAIN_NAME}/g" /etc/nginx/nginx.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
