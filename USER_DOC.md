# Inception User Documentation

## Service Overview

Inception provides a WordPress website and several administration and monitoring
services. Docker Compose starts them as one stack.

| Service | Purpose | User access |
| --- | --- | --- |
| Nginx | Secure TLS entry point for WordPress | `https://iel-asef.42.fr/` |
| WordPress/PHP-FPM | Website, content management, and PHP execution | Through Nginx |
| MariaDB | Stores WordPress users, content, and settings | Internal network only |
| Redis | WordPress object cache | Internal network only |
| FTP | Authenticated access to WordPress files | Port `21`, passive `21000-21010` |
| Adminer | Browser-based database administration | `http://localhost:8082/` |
| Static website | Independent Nginx-hosted site | `http://localhost:8081/` |
| Uptime Kuma | Service monitoring dashboard | `http://localhost:3001/` |

## Starting and Stopping

Run commands from the repository root.

Start and build everything:

```bash
make
```

Stop containers without removing them:

```bash
make stop
```

Start the existing containers again:

```bash
make start
```

Restart all existing containers:

```bash
make restart
```

Remove the containers and Compose network:

```bash
make down
```

`make fclean` also removes Compose volume objects and project images. The
bind-mounted data under `/home/iel-asef/data` remains on the host, so treat
`fclean` as infrastructure cleanup rather than data erasure.

## Accessing the Services

### WordPress Website

Open:

```text
https://iel-asef.42.fr/
```

If the domain does not resolve, ensure `/etc/hosts` contains:

```text
127.0.0.1 iel-asef.42.fr
```

The TLS certificate is self-signed. A browser may display a local certificate
warning on the first visit. Confirm that the address is the configured local
domain before accepting the local trust exception.

`https://localhost/` and `https://127.0.0.1/` also reach Nginx for local testing,
but WordPress keeps `https://iel-asef.42.fr/` as its canonical URL.

### WordPress Administration

Open:

```text
https://iel-asef.42.fr/wp-admin/
```

Sign in with `WP_ADMIN_USER` and `WP_ADMIN_PASS` from `srcs/.env`.

### Database Administration

Open Adminer at:

```text
http://localhost:8082/
```

Use these values from `srcs/.env`:

| Adminer field | Value source |
| --- | --- |
| System | MariaDB or MySQL |
| Server | `mariadb` |
| Username | `MYSQL_USER` |
| Password | `MYSQL_PASSWORD` |
| Database | `MYSQL_DATABASE` |

Do not use `localhost` as the Adminer database server. Adminer runs in a separate
container and reaches the database by its Compose service name, `mariadb`.

### Static Website

Open `http://localhost:8081/`. This site is independent from WordPress and is served
by the `static` container.

### Uptime Kuma

Open `http://localhost:3001/`. On first use, complete Uptime Kuma's account and
database setup in the browser. Its application data persists in the
`uptime_kuma_data` volume backed by `/home/iel-asef/data/uptime-kuma`.

### FTP

Configure an FTP client with:

| Setting | Value |
| --- | --- |
| Host | `localhost` |
| Port | `21` |
| Username | `FTP_USER` from `srcs/.env` |
| Password | `FTP_PASSWORD` from `srcs/.env` |
| Mode | Passive |
| Passive port range | `21000-21010` |

The FTP service exposes the same files used by WordPress, PHP-FPM, and Nginx.
File changes can therefore affect the live website.

## Credentials

Local credentials are stored in `srcs/.env`. The file contains:

- MariaDB database, application user, and root password
- WordPress administrator and author accounts
- WordPress domain information
- FTP account credentials

Recommended handling:

```bash
chmod 600 srcs/.env
```

- Replace default or example values before the first start.
- Do not paste credentials into issue reports or logs.
- Do not publish a real `.env` file in a public repository.
- Stop the stack before performing manual database or storage maintenance.
- Use Docker secrets instead of environment variables for a production system.

Uptime Kuma creates its own administrator during browser-based first-run setup.
Its credentials are not stored in `srcs/.env`.

## Checking Service Health

Show the current state:

```bash
make ps
```

All services should show `Up` and `healthy`. Run the complete functional check
with:

```bash
make test
```

Follow all logs:

```bash
make logs-follow
```

Use `make logs` instead to print the latest 200 lines and return immediately.

Inspect one service:

```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
docker logs static
```

Basic endpoint tests:

```bash
curl -kI https://iel-asef.42.fr/
curl -I http://localhost:8081/
curl -I http://localhost:8082/
curl -I http://localhost:3001/
```

Expected results are a successful `2xx` response or, for an application setup or
login route, a normal `3xx` redirect.

Check the database from inside its container without publishing port `3306`:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env \
  exec mariadb mariadb-admin ping
```

## Common Problems

### Docker Permission Denied

Ensure Docker is running and the current account is allowed to use the Docker
daemon. Depending on the host configuration, Docker commands may require `sudo`
or membership in the `docker` group.

### A Published Port Is Already in Use

Check host listeners and stop the conflicting process before restarting the
stack:

```bash
ss -ltn
```

### WordPress Domain Does Not Open

Check `DOMAIN_NAME` in `srcs/.env`, verify `/etc/hosts`, and use `https://` rather
than plain HTTP.

### Empty `docker logs static`

Generate a request with `curl http://localhost/`. The static Nginx configuration
sends access logs to Docker stdout, so the request should then appear in
`docker logs static`.

### A Service Keeps Restarting

Inspect its recent logs and the Compose state:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps -a
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs --tail=100
```

Fix the first reported configuration or permission error, rebuild with
`make up`, and confirm the container remains `Up`.
