FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    build-essential \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone --branch 2.4.0 --depth 1 \
    https://github.com/louislam/uptime-kuma.git .

RUN npm run setup

RUN mkdir -p /app/data

COPY tools/start.sh /usr/local/bin/start-kuma.sh

RUN chmod +x /usr/local/bin/start-kuma.sh

EXPOSE 3001

ENTRYPOINT ["/usr/local/bin/start-kuma.sh"]