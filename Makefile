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
	$(COMPOSE) down
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

fclean:
	rm -fr $(DATA_PATH)/db-data $(DATA_PATH)/html

logs:
	$(COMPOSE) logs -f

.PHONY: up down re logs
