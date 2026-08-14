NAME := inception

COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE := srcs/.env
COMPOSE := docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

DATA_ROOT := /home/iel-asef/data
DATA_DIRS := $(DATA_ROOT)/mariadb \
             $(DATA_ROOT)/wordpress \
             $(DATA_ROOT)/redis \
             $(DATA_ROOT)/uptime-kuma

.DEFAULT_GOAL := all

.PHONY: all prepare build up down start stop restart \
        clean fclean re logs ps

all: up

prepare:
	@echo "Creating data directories..."
	@mkdir -p $(DATA_DIRS)

build: prepare
	@echo "Building Docker images..."
	@$(COMPOSE) build

up: prepare
	@echo "Starting Inception..."
	@$(COMPOSE) up -d --build

down:
	@echo "Stopping and removing containers..."
	@$(COMPOSE) down --remove-orphans

start:
	@echo "Starting existing containers..."
	@$(COMPOSE) start

stop:
	@echo "Stopping containers..."
	@$(COMPOSE) stop

restart:
	@echo "Restarting containers..."
	@$(COMPOSE) restart

clean:
	@echo "Removing containers and networks..."
	@$(COMPOSE) down --remove-orphans

fclean:
	@echo "Removing containers, networks, volumes and local images..."
	@$(COMPOSE) down --volumes --rmi local --remove-orphans

re: fclean all

logs:
	@$(COMPOSE) logs -f

ps:
	@$(COMPOSE) ps