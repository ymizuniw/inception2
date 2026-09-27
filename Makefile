NAME=Inception
COMPOSE=docker compose -p inception -f srcs/docker-compose.yml

include srcs/.env
export

up:
	mkdir -p $(DATA_PATH)/db-data $(DATA_PATH)/html
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

re:
	mkdir -p $(DATA_PATH)/db-data $(DATA_PATH)/html
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

logs:
	$(COMPOSE) logs -f

.PHONY: up down re logs
