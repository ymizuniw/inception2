FROM alpine:3.23

RUN apk add --no-cache \
	bash \
	mariadb \
	mariadb-client

COPY conf/custom.cnf /etc/mysql/mariadb.conf.d/99-custom.cnf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

# docker compose build --no-cache mariadb
# docker compose up mariadb
