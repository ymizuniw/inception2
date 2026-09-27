NAME=Inception

up:
	docker compose up

down:
	docker compose down

re:
	docker compose build --no-cache
	docker compose up

.PHONY up down re