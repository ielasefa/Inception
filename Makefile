COMPOSE := docker compose -f srcs/docker-compose.yml --env-file srcs/.env
DOMAIN := $(shell sed -n 's/^DOMAIN_NAME=//p' srcs/.env)
DATA_DIR := $(shell sed -n 's/^DATA_PATH=//p' srcs/.env)

.PHONY: all prepare build up down start stop restart ps logs logs-follow \
	clean fclean re hosts cert-install test

all: up

prepare:
	@echo "Preparing data directories in $(DATA_DIR)"
	@mkdir -p \
		$(DATA_DIR)/mariadb \
		$(DATA_DIR)/wordpress \
		$(DATA_DIR)/redis \
		$(DATA_DIR)/uptime-kuma
	@echo "Data directories are ready."

build: prepare
	@echo "Building Docker images..."
	$(COMPOSE) build

up: prepare
	@echo "Starting Inception..."
	$(COMPOSE) up -d --build --remove-orphans

down:
	@echo "Stopping Inception without deleting data..."
	$(COMPOSE) down --remove-orphans

start:
	@echo "Starting existing containers..."
	$(COMPOSE) start

stop:
	@echo "Stopping containers..."
	$(COMPOSE) stop

restart:
	@echo "Restarting Inception..."
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs --tail=200

logs-follow:
	@echo "Following logs; press Ctrl+C to stop."
	$(COMPOSE) logs --tail=200 -f

clean:
	@echo "Removing containers and networks; keeping volumes..."
	$(COMPOSE) down --remove-orphans

fclean:
	@echo "Removing containers, Compose volumes, and local images; keeping host data..."
	$(COMPOSE) down --volumes --rmi local --remove-orphans

re: fclean all

hosts:
	@echo "Configuring /etc/hosts..."
	@grep -qw "$(DOMAIN)" /etc/hosts || \
		echo "127.0.0.1 $(DOMAIN)" | sudo tee -a /etc/hosts >/dev/null
	@echo "$(DOMAIN) is configured."

cert-install:
	@echo "Copying Nginx certificate..."
	@docker cp nginx:/etc/ssl/certs/server.crt /tmp/iel-asef-inception.crt
	@sudo cp /tmp/iel-asef-inception.crt \
		/usr/local/share/ca-certificates/iel-asef-inception.crt
	@sudo update-ca-certificates
	@echo "Certificate installed successfully."

test:
	@echo "Checking Compose configuration..."
	@$(COMPOSE) config --quiet
	@echo "Checking container state..."
	@$(COMPOSE) ps
	@docker exec mariadb sh -c \
		'mariadb -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE" -Nse "SELECT 1"' \
		| grep -qx 1
	@docker exec redis redis-cli ping | grep -qx PONG
	@docker exec wordpress wp core is-installed --allow-root
	@docker exec wordpress wp redis status --allow-root | grep -q "Status: Connected"
	@docker exec ftp pgrep -x vsftpd >/dev/null
	@curl -kfsS --resolve $(DOMAIN):443:127.0.0.1 \
		https://$(DOMAIN)/ >/dev/null
	@curl -fsS http://127.0.0.1:8081/ >/dev/null
	@curl -fsS http://127.0.0.1:8082/ >/dev/null
	@curl -fsS http://127.0.0.1:3001/ >/dev/null
	@echo "All service checks passed."
