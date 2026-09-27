#!/bin/bash

if [ -d "/run/mysqld" ]; then
    echo "[i] mysqld already present, skipping creation"
    chown -R mysql:mysql /run/mysqld
else
    echo "[i] mysqld not found, creating...."
    mkdir -p /run/mysqld
    chown -R mysql:mysql /run/mysqld
fi

if [ -d ${WP_DATABASE_PATH}/mysql ]; then
    echo "[i] DB data directory already present, skipping creation"
    chown -R mysql:mysql ${WP_DATABASE_PATH}
else
    echo "[i] DB data directory not found, creating initial DBs"
    chown -R mysql:mysql ${WP_DATABASE_PATH}

    # init sql
    DATABASE_ROOT_PASSWORD=$(cat /run/secrets/database_root_password)
    DATABASE_USER_PASSWORD=$(cat /run/secrets/database_user_password)
    : "${DATABASE_ROOT_PASSWORD:?root password is empty}"
    : "${DATABASE_USER_PASSWORD:?user password is empty}"
    : "${DATABASE_NAME:?DATABASE_NAME is not set}"
    : "${DATABASE_USER:?DATABASE_USER is not set}"

    if ! mariadb-install-db --user=mysql --datadir=${WP_DATABASE_PATH} --skip-test-db > /dev/null; then
	echo "[FAIL] mariadb-install-db --user=mysql --datadir=${WP_DATABASE_PATH} --skip-test-db" >&2
        exit 1
    fi

    echo "[i] Creating database: $DATABASE_NAME"
    echo "[i] Creating user: $DATABASE_USER"

    # setup
    if ! /usr/bin/mariadbd --user=mysql --bootstrap --verbose=0 << EOF
    FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`$DATABASE_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DATABASE_USER'@'%' IDENTIFIED BY '$DATABASE_USER_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DATABASE_NAME\`.* TO '$DATABASE_USER'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DATABASE_ROOT_PASSWORD';
EOF
    then
	echo "[FAIL] mariadbd --bootstrap" >&2
	exit 1
    fi
    echo "[i] DB init process done"
fi

exec /usr/bin/mariadbd --user=mysql --skip-networking=0
# --skip-networking=0 : not skip TCP networking
# --console : for debug
