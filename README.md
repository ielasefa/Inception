*This project has been created as part of the 42 curriculum by iel-asef.*

# Inception

## Description

Inception is a system-administration project that builds a complete web stack
with Docker and Docker Compose. Its goal is to separate infrastructure concerns
into dedicated containers, connect them through an isolated network, and keep
application data persistent across container recreation.

The mandatory stack contains Nginx with TLS, WordPress with PHP-FPM, and
MariaDB. This repository also implements the bonus services Redis, FTP,
Adminer, a static website, and Uptime Kuma.

## Project Description

### Architecture

Every service is built from a project-owned Dockerfile based on Debian
Bullseye. Docker Compose builds the images, creates the containers and private
network, publishes only user-facing ports, and attaches persistent storage.

```text
Browser --HTTPS:443--> Nginx --FastCGI:9000--> WordPress/PHP-FPM
                                             |               |
                                             |               +--Redis:6379
                                             +--MariaDB:3306

Host --HTTP:8081---> Static website
Host --HTTP:8082---> Adminer --------MariaDB:3306
Host --FTP:21------> FTP ------------shared WordPress files
Host --HTTP:3001---> Uptime Kuma
```

MariaDB, WordPress/PHP-FPM, and Redis are not published directly to the host.
Containers reach them by their Compose service names on the `inception` bridge
network.

### Services

| Service | Purpose | Published access | Persistent data |
| --- | --- | --- | --- |
| Nginx | TLS termination and WordPress reverse proxy | `443` | Shares WordPress files |
| WordPress | CMS and PHP-FPM application server | Internal `9000` | `wordpress_data` |
| MariaDB | WordPress relational database | Internal `3306` | `mariadb_data` |
| Redis | WordPress object cache | Internal `6379` | `redis_data` |
| FTP | Authenticated access to WordPress files | `21`, `21000-21010` | Shares `wordpress_data` |
| Adminer | Browser-based database administration | `8082` | None |
| Static | Independent Nginx-hosted website | `8081` | None |
| Uptime Kuma | Service monitoring dashboard | `3001` | `uptime_kuma_data` |

### Included Sources

| Path | Purpose |
| --- | --- |
| `srcs/docker-compose.yml` | Defines services, networking, ports, dependencies, and volumes. |
| `srcs/requirements/mariadb/` | MariaDB image, server configuration, and initialization script. |
| `srcs/requirements/wordpress/` | PHP-FPM image, pool configuration, and WordPress setup script. |
| `srcs/requirements/nginx/` | TLS-enabled Nginx image and WordPress server configuration. |
| `srcs/requirements/bonus/` | Redis, FTP, Adminer, static website, and Uptime Kuma sources. |
| `srcs/.env` | Local Compose configuration and credentials. |
| `Makefile` | Build, lifecycle, validation, host, and certificate commands. |
| `USER_DOC.md` | End-user and administrator instructions. |
| `DEV_DOC.md` | Developer setup, maintenance, and persistence documentation. |

WordPress is downloaded and configured with WP-CLI. Adminer and Uptime Kuma are
retrieved from their upstream projects while their images are built. The other
services are installed from Debian packages and configured by repository-owned
files.

### Main Design Choices

- Each container runs one main service in the foreground.
- Debian Bullseye is used consistently as the base image.
- Nginx is the only public entry point for the mandatory WordPress stack.
- Nginx accepts TLS 1.2 and TLS 1.3 connections on port `443`.
- Service discovery uses Compose DNS names instead of fixed container IPs.
- WordPress waits for an authenticated MariaDB connection before installation.
- Initialization scripts are repeatable and preserve existing application data.
- Redis is connected to WordPress through the Redis Object Cache plugin.
- Named volumes use bind-backed directories below `DATA_PATH`.
- Nginx generates a self-signed certificate for `DOMAIN_NAME` during its build.

### Virtual Machines vs Docker

| Virtual machines | Docker containers |
| --- | --- |
| Virtualize hardware and run a complete guest operating system. | Isolate processes while sharing the host kernel. |
| Usually consume more memory, disk space, and startup time. | Usually start faster and use fewer resources. |
| Can run a kernel different from the host kernel. | Package the application and its user-space dependencies. |
| Provide full-machine isolation. | Provide lightweight service-level isolation. |

Docker is appropriate here because Inception focuses on reproducible service
images, isolated processes, private networking, and persistent data without
requiring one complete virtual machine per service.

### Secrets vs Environment Variables

| Docker secrets | Environment variables |
| --- | --- |
| Designed for sensitive values and exposed only to selected services. | Convenient for application and Compose configuration. |
| Commonly mounted as files under `/run/secrets/`. | Visible through container inspection and process environments. |
| Preferred for production credentials. | Suitable for non-sensitive settings and controlled local development. |

This project currently reads its local settings and credentials from
`srcs/.env`. That file must have restricted permissions, must not be published,
and should contain non-default passwords. A production deployment should move
passwords to Docker secrets and keep only non-sensitive configuration in the
environment.

### Docker Network vs Host Network

| Docker bridge network | Host network |
| --- | --- |
| Gives containers isolated interfaces and service-name DNS. | Shares the host network namespace directly. |
| Requires explicit port publishing for host access. | Uses host ports without Compose port mappings. |
| Reduces accidental exposure of internal services. | Provides less isolation and increases port-conflict risk. |

Inception uses the user-defined `inception` bridge network. Only Nginx and the
user-facing bonus services publish host ports.

### Docker Volumes vs Bind Mounts

| Docker volumes | Bind mounts |
| --- | --- |
| Managed by Docker and referenced by a stable volume name. | Map an exact host path into a container. |
| Decoupled from a specific repository path. | Easy to locate, inspect, and back up on the host. |
| Convenient for container-managed application state. | Useful when data must live at a required host location. |

This project combines both approaches: Compose declares named volumes, and the
local volume driver binds them to directories below `DATA_PATH`. This preserves
stable Compose volume names while storing data under `/home/<login>/data`, as
required by the project. FTP mounts the same WordPress volume used by Nginx and
PHP-FPM.

## Instructions

### Prerequisites

- A Linux host or Linux virtual machine
- Docker Engine with the Docker Compose plugin
- GNU Make
- Permission to communicate with the Docker daemon
- Free host ports `21`, `443`, `3001`, `8081`, `8082`, and `21000-21010`

Check the required tools:

```bash
docker --version
docker compose version
make --version
```

### Configuration

Edit `srcs/.env` before the first startup. At minimum, configure these groups:

| Variables | Purpose |
| --- | --- |
| `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` | WordPress database and application account |
| `MYSQL_ROOT_PASSWORD` | MariaDB root account |
| `DOMAIN_NAME` | Local HTTPS domain used by Nginx and WordPress |
| `WP_ADMIN_USER`, `WP_ADMIN_PASS`, `WP_ADMIN_EMAIL` | WordPress administrator |
| `WP_USER_USER`, `WP_USER_PASS`, `WP_USER_EMAIL` | Additional WordPress author |
| `FTP_USER`, `FTP_PASSWORD` | FTP account |
| `DATA_PATH` | Host directory containing persistent service data |

Use strong passwords and restrict the file:

```bash
chmod 600 srcs/.env
```

Set `DATA_PATH` to `/home/<login>/data`. The supplied domain also needs a local
host entry:

```text
127.0.0.1 iel-asef.42.fr
```

The Makefile can add the entry using the current `DOMAIN_NAME` value:

```bash
make hosts
```

This command uses `sudo` when it must update `/etc/hosts`.

### Build and Run

From the repository root, run:

```bash
make
```

This creates the host data directories, builds all images, removes stale
Compose orphans, and starts the stack in detached mode. Confirm the result with:

```bash
make ps
make test
```

### Makefile Commands

| Command | Action |
| --- | --- |
| `make` / `make up` | Prepare storage, build images, and start the stack. |
| `make prepare` | Create the persistent host directories. |
| `make build` | Build all images without starting containers. |
| `make ps` | Display the current container state and published ports. |
| `make test` | Run Compose, database, Redis, WordPress, FTP, and HTTP checks. |
| `make logs` | Print the latest 200 log lines and exit. |
| `make logs-follow` | Follow container logs until `Ctrl+C`. |
| `make stop` / `make start` | Stop or start existing containers. |
| `make restart` | Restart existing containers. |
| `make down` | Remove containers and the Compose network while keeping data. |
| `make clean` | Same cleanup behavior as `make down`. |
| `make fclean` | Also remove Compose volumes and locally built images. |
| `make re` | Run `fclean`, rebuild, and restart the project. |
| `make hosts` | Add `DOMAIN_NAME` to `/etc/hosts` when missing. |
| `make cert-install` | Install the running Nginx certificate in the system trust store. |

`make fclean` removes the Compose volume objects, but it does not delete the
bind-mounted files below `DATA_PATH`.

### Access

| Service | Address |
| --- | --- |
| WordPress | `https://iel-asef.42.fr/` |
| WordPress administration | `https://iel-asef.42.fr/wp-admin/` |
| Local Nginx TLS check | `https://localhost/` or `https://127.0.0.1/` |
| Static website | `http://localhost:8081/` |
| Adminer | `http://localhost:8082/` |
| Uptime Kuma | `http://localhost:3001/` |
| FTP | `localhost:21`, passive ports `21000-21010` |

For Adminer, use `mariadb` as the database server and the `MYSQL_*` application
credentials from `srcs/.env`. For FTP, use `FTP_USER` and `FTP_PASSWORD` from
the same file.

The Nginx certificate is self-signed. A browser security warning is expected
until the certificate is trusted locally. Run `make cert-install` only after the
Nginx container is running. Firefox may require importing the certificate into
its own certificate store, depending on the browser configuration.

### Persistent Data

| Data | Compose volume | Default host location |
| --- | --- | --- |
| MariaDB databases | `mariadb_data` | `${DATA_PATH}/mariadb` |
| WordPress files and uploads | `wordpress_data` | `${DATA_PATH}/wordpress` |
| Redis state | `redis_data` | `${DATA_PATH}/redis` |
| Uptime Kuma state | `uptime_kuma_data` | `${DATA_PATH}/uptime-kuma` |

Changing or recreating a container does not remove this data. Changing a
password in `srcs/.env` also does not automatically update credentials already
stored in an initialized MariaDB or WordPress volume.

### Verification

Run the complete project check:

```bash
make test
```

Useful manual checks:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env config --quiet
docker compose -f srcs/docker-compose.yml --env-file srcs/.env ps -a
curl -kI https://iel-asef.42.fr/
curl -I http://localhost:8081/
curl -I http://localhost:8082/
curl -I http://localhost:3001/
```

### Common Problems

#### Plain HTTP Sent to the HTTPS Port

Port `443` accepts TLS only. Use `https://localhost/` or
`https://iel-asef.42.fr/`, not `http://localhost:443/`.

#### Browser Security Warning

The certificate is self-signed. Confirm that the address is the configured
local domain, then add a local exception or install the certificate with
`make cert-install`.

#### Connection Refused

Check the stack and the failing service logs:

```bash
make ps
make logs
```

Also confirm that another process is not already using a published port.

#### Missing Environment Variable Warning

Ensure the variable name in `srcs/.env` exactly matches the reference in
`srcs/docker-compose.yml`. Then validate the configuration with:

```bash
docker compose -f srcs/docker-compose.yml --env-file srcs/.env config --quiet
```

#### Volume Mount Error

Confirm that `DATA_PATH` is an absolute writable path and run `make prepare`
before starting the stack.

More operational details are available in [USER_DOC.md](USER_DOC.md). Developer
setup and maintenance details are available in [DEV_DOC.md](DEV_DOC.md).

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [Docker bridge networking](https://docs.docker.com/engine/network/drivers/bridge/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)
- [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Nginx documentation](https://nginx.org/en/docs/)
- [Nginx FastCGI module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [WordPress documentation](https://wordpress.org/documentation/)
- [WP-CLI command reference](https://developer.wordpress.org/cli/commands/)
- [MariaDB Server documentation](https://mariadb.com/docs/server/)
- [Redis documentation](https://redis.io/docs/latest/)
- [Adminer documentation](https://www.adminer.org/)
- [vsftpd manual](https://security.appspot.com/vsftpd/vsftpd_conf.html)
- [Uptime Kuma repository](https://github.com/louislam/uptime-kuma)

### Use of AI

AI assistance was used to diagnose Docker build and startup errors, compare the
Compose configuration with Dockerfiles and startup scripts, improve service and
volume validation, and draft and review the project documentation. The project
was then checked with Docker Compose validation, container status, service logs,
authenticated database queries, Redis and WordPress checks, FTP checks, HTTP
requests, and persistent-volume inspection. AI output was reviewed against the
actual repository and was not used as a substitute for understanding or testing
the architecture.
