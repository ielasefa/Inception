# Inception Developer Documentation

## Development Overview

The project uses Docker Compose to build and run a group of custom Debian-based
images. The repository owns the Dockerfiles, service configuration, entrypoint
scripts, static source files, Compose topology, and Makefile workflow.

The mandatory request path is:

```text
Nginx:443 -> WordPress/PHP-FPM:9000 -> MariaDB:3306
```

All containers join the user-defined `inception` bridge network. Internal
services use Compose DNS names rather than container IP addresses.

## Prerequisites

Install and verify:

- Linux with a running Docker Engine
- Docker Compose plugin (`docker compose`, not the legacy Python executable)
- GNU Make
- Git
- Internet access during uncached builds for Debian packages and upstream source
  downloads

```bash
docker --version
docker compose version
docker info
make --version
git --version
```

The user running the project must have access to the Docker daemon and permission
to create directories under `$HOME/data`.

## Repository Layout

```text
.
|-- Makefile
|-- README.md
|-- USER_DOC.md
|-- DEV_DOC.md
`-- srcs
    |-- .env
    |-- docker-compose.yml
    `-- requirements
        |-- mariadb
        |-- nginx
        |-- wordpress
        `-- bonus
            |-- adminer
            |-- ftp
            |-- redis
            |-- static
            `-- uptime-kuma
```

Each service directory generally contains:

- `Dockerfile` or `dockerfile`: image build instructions
- `conf/`: daemon or application configuration
- `tools/`: initialization and foreground startup scripts
- application assets where applicable

## Setup From Scratch

### 1. Clone and Enter the Repository

```bash
git clone <repository-url> Inception
cd Inception
```

### 2. Configure the Environment

Edit `srcs/.env`. The current Compose stack consumes these variables:

| Variable | Purpose |
| --- | --- |
| `MYSQL_DATABASE` | WordPress database name |
| `MYSQL_USER` | MariaDB application user |
| `MYSQL_PASSWORD` | MariaDB application-user password |
| `MYSQL_ROOT_PASSWORD` | MariaDB root password |
| `WP_URL` | Canonical WordPress HTTPS URL |
| `WP_TITLE` | WordPress title used during first installation |
| `WP_ADMIN_USER` | WordPress administrator login |
| `WP_ADMIN_PASS` | WordPress administrator password |
| `WP_ADMIN_EMAIL` | WordPress administrator email |
| `WP_USER_USER` | Secondary WordPress author login |
| `WP_USER_PASS` | Secondary WordPress author password |
| `WP_USER_EMAIL` | Secondary WordPress author email |
| `DOMAIN_NAME` | Local domain used by WordPress and the TLS certificate |
| `DATA_PATH` | Host persistence root, normally `/home/<login>/data` |
| `FTP_USER` | FTP login |
| `FTP_PASSWORD` | FTP password |

Use distinct WordPress emails and non-default passwords. Keep the file readable
only by its owner:

```bash
chmod 600 srcs/.env
```

The current project passes values through Compose environment variables. This is
convenient for local development but not the preferred production secret model.
For production, create Docker secrets, grant each secret only to its consumer,
and update entrypoints to read the corresponding `/run/secrets/*` files.

### 3. Configure Local Name Resolution

Map the value of `DOMAIN_NAME` to the local machine. With the supplied project
domain, `/etc/hosts` needs:

```text
127.0.0.1 iel-asef.42.fr
```

### 4. Check Ports and Storage Paths

The stack publishes host ports `21`, `443`, `3001`, `8081`, `8082`, and
`21000-21010`. Check for conflicts before startup:

```bash
ss -ltn
```

`make prepare` creates the directories configured by `DATA_PATH`. With the
supplied configuration, the persistent directories are:

```text
/home/iel-asef/data/mariadb
/home/iel-asef/data/wordpress
/home/iel-asef/data/redis
/home/iel-asef/data/uptime-kuma
```

If the project runs under another login, update `DATA_PATH` in `srcs/.env`
before starting.

## Build and Launch

Build and start the complete stack:

```bash
make
```

Equivalent explicit Compose command:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env \
  up -d --build --remove-orphans
```

Build without starting:

```bash
make build
```

Force a clean Compose rebuild:

```bash
make re
```

`make re` removes Compose volume objects and local project images before
rebuilding. Host data below `DATA_PATH` remains available to the recreated
volumes.

## Container Management

```bash
make ps
make test
make logs
make logs-follow
make stop
make start
make restart
make down
```

`make logs` prints recent output and exits. `make logs-follow` keeps streaming
output until `Ctrl+C` is pressed.

Direct Compose equivalents and diagnostics:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps -a
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs --tail=100
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs -f mariadb
docker compose -f srcs/docker-compose.yml --env-file srcs/.env exec wordpress sh
docker compose -f srcs/docker-compose.yml --env-file srcs/.env exec mariadb sh
```

Validate Compose before a build:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env config --quiet
```

Validate service configuration inside running containers:

```bash
docker exec nginx nginx -t
docker exec static nginx -t
docker exec wordpress php-fpm7.4 -t
docker exec redis redis-cli ping
```

Run an authenticated MariaDB query without exposing its port:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env \
  exec mariadb sh -c \
  'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SELECT 1"'
```

## Service Build Notes

### MariaDB

`srcs/requirements/mariadb/tools/init.sh` initializes the data directory,
creates the configured database and users, and then replaces itself with
`mariadbd` in the foreground. Its configuration source is named
`conf/50-server.conf` and is copied to the conventional container destination
`/etc/mysql/mariadb.conf.d/50-server.cnf`.

### WordPress

The WordPress entrypoint waits for an authenticated MariaDB query, downloads
WordPress with WP-CLI when needed, writes database constants, installs the site
and users idempotently, fixes ownership, and starts PHP-FPM in the foreground.

### Nginx

The image generates a self-signed certificate for `DOMAIN_NAME`, copies the full
Nginx configuration, and forwards PHP requests to `wordpress:9000`. Rebuild the
Nginx image after changing the domain so the generated certificate is updated.

### Bonus Services

- Redis runs on the internal network, persists in `redis_data`, and provides the
  WordPress object cache.
- FTP shares `wordpress_data` and uses passive ports `21000-21010`.
- Adminer uses Apache/PHP and listens on host and container port `8082`.
- The static service builds from the lowercase
  `srcs/requirements/bonus/static/dockerfile` and publishes host port `8081`.
- Uptime Kuma stores its state in `uptime_kuma_data` and publishes port `3001`.

## Persistence

| Data | Compose volume | Storage type | Location |
| --- | --- | --- | --- |
| MariaDB tables | `mariadb_data` | Local volume backed by a bind mount | `/home/iel-asef/data/mariadb` |
| WordPress core, configuration, and uploads | `wordpress_data` | Local volume backed by a bind mount | `/home/iel-asef/data/wordpress` |
| Redis data | `redis_data` | Local volume backed by a bind mount | `/home/iel-asef/data/redis` |
| Uptime Kuma data | `uptime_kuma_data` | Local volume backed by a bind mount | `/home/iel-asef/data/uptime-kuma` |

Inspect volume metadata:

```bash
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
docker volume inspect srcs_redis_data
docker volume inspect srcs_uptime_kuma_data
```

Containers and images are disposable; persistent application state must live in
the declared volumes. Back up the directories below `DATA_PATH` before deleting
or manually changing them.

## Development Workflow

After editing one service, rebuild only that service when possible:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env \
  up -d --build mariadb
```

Then check its state and logs:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps mariadb
docker compose -f srcs/docker-compose.yml --env-file srcs/.env logs --tail=100 mariadb
```

After changes to shared storage, WordPress, or service dependencies, run the full
`make up` workflow and retest the public endpoints.

Recommended pre-commit checks:

```bash
bash -n srcs/requirements/mariadb/tools/init.sh
bash -n srcs/requirements/wordpress/tools/init.sh
docker compose -f srcs/docker-compose.yml --env-file srcs/.env config --quiet
git diff --check
```

## Troubleshooting

### Build Context or COPY Failure

Docker `COPY` sources are relative to a service's build context and are
case-sensitive. Verify the source file with `find` and keep the Dockerfile source
name synchronized. For example, the MariaDB source is `50-server.conf`, not
`50-server.cnf`.

### Container Starts Before a Dependency Is Ready

`depends_on` controls creation order but a startup script should still perform a
real readiness check. WordPress therefore waits until it can authenticate and run
a MariaDB query rather than relying only on process existence.

### Persistent Credentials Changed

Changing `.env` does not automatically rewrite every application record already
stored in a persistent database. Review entrypoint behavior, update the account
through the application/database when appropriate, and avoid deleting data as a
first response.

### Logs Are Empty

Daemons must log to stdout/stderr for `docker logs` to display useful output. The
static Nginx configuration explicitly routes access logs to `/dev/stdout` and
errors to `/dev/stderr`.

### Service Is Reachable Inside Docker but Not From the Host

Compare the daemon's listening port with the Compose mapping in
`HOST_PORT:CONTAINER_PORT` form, then inspect host listeners and firewall rules.

## Security Notes

- Do not bake passwords or `.env` files into images.
- Do not publish MariaDB, Redis, or PHP-FPM ports unless explicitly required.
- Replace self-signed certificates with certificates from a trusted authority for
  public deployment.
- Restrict the FTP account and review file ownership on shared WordPress storage.
- Pin and review downloaded upstream versions before production use.
- Migrate sensitive environment variables to Docker secrets outside the local
  educational environment.
