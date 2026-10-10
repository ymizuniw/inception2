#!/bin/bash

read_env(){
    DATABASE_PASSWORD="$(cat /run/secrets/database_user_password)"
    : "${DATABASE_PASSWORD:?user password is empty}"
    : "${DATABASE_NAME:?DATABASE_NAME is not set}"
    : "${DATABASE_USER:?DATABASE_USER is not set}"
    : "${DATABASE_HOST:?DATABASE_HOST is not set}"
    : "${DOMAIN_NAME:?DOMAIN_NAME is not set}"
    : "${WP_ADMIN_USER:?WP_ADMIN_USER is not set}"
    : "${WP_USER:?WP_USER is not set}"
    : "${WP_USER_EMAIL:?WP_USER_EMAIL is not set}"
    WP_URL="https://${DOMAIN_NAME}"
}

contains_admin(){
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | grep -q admin
}

validate_admin_credentials(){
    local admin_password
    admin_password="$(cat /run/secrets/wp_admin_password)"
    : "${admin_password:?wp_admin_password is empty}"
    if contains_admin "${WP_ADMIN_USER}"; then
        echo "[FAIL] WP_ADMIN_USER must not contain 'admin' (case-insensitive)" >&2
        exit 1
    fi
    if contains_admin "${admin_password}"; then
        echo "[FAIL] wp_admin_password must not contain 'admin' (case-insensitive)" >&2
        exit 1
    fi
}

wait_for_db(){
    for i in {30..0}; do
        if [ "$i" -eq 0 ]; then
            echo "db timed out" >&2
            exit 1
        fi
        if mariadb -h "${DATABASE_HOST}" -u "${DATABASE_USER}" -p"${DATABASE_PASSWORD}" "${DATABASE_NAME}" -e "SELECT 1" >/dev/null; then
            echo "[SUCCESS] mariadb is working"
            break
        else
            echo "[FAIL] mariadb -h ${DATABASE_HOST}  -u  ${DATABASE_USER}  ${DATABASE_NAME}  -e \"SELECT 1;\""
        fi
        sleep 1
    done
}

# // wp-config-sample.php
# define( 'DB_NAME', 'database_name_here' );
# define( 'DB_USER', 'username_here' );
# define( 'DB_PASSWORD', 'password_here' );
# define( 'DB_HOST', 'localhost' );

install_wordpress(){

    curl -sS -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    if ! php wp-cli.phar --info >/dev/null; then
        echo "[FAIL] php wp-cli.phar --info"
        exit 1
    fi
    echo "chmod +x wp-cli.phar"
    chmod +x wp-cli.phar
    echo "mv wp-cli.phar /usr/local/bin/wp"
    mv wp-cli.phar /usr/local/bin/wp
    if ! wp --info >/dev/null; then
        echo "[FAIL] wp --info"
        exit 1
    fi
    echo "wp core download"
    if ! wp core download --path="${WP_FILE_PATH}" --force >/dev/null; then
        echo "[FAIL] wp core download"
        exit 1
    fi
    echo "wp config create"
    if ! wp config create --path="${WP_FILE_PATH}" --dbname="${DATABASE_NAME}" --dbuser="${DATABASE_USER}" --dbpass="$(cat /run/secrets/database_user_password)" --dbhost="${DATABASE_HOST}" --force --quiet >/dev/null; then
        echo "[FAIL] wp config create"
        exit 1
    fi
    echo "wp core install"
    if ! wp core install --path="${WP_FILE_PATH}" --url="${WP_URL}" --title="${WP_SITE_TITLE}" --admin_user="${WP_ADMIN_USER}" --admin_password="$(cat /run/secrets/wp_admin_password)" --locale="${WP_LOCALE}" --admin_email="${WP_ADMIN_EMAIL}" --skip-email="${WP_ADMIN_EMAIL}" >/dev/null; then
        # --debug
        echo "[FAIL] wp core install"
        exit 1
    fi
    echo "wp user create (second, non-admin account)"
    if ! wp user create "${WP_USER}" "${WP_USER_EMAIL}" --path="${WP_FILE_PATH}" --role=author --user_pass="$(cat /run/secrets/wp_user_password)" >/dev/null; then
        echo "[FAIL] wp user create"
        exit 1
    fi
    echo "wp plugin update"
    if ! wp plugin update --path="${WP_FILE_PATH}" --all >/dev/null; then
        echo "[FAIL] wp plugin update"
        exit 1
    fi
    echo "wp installation succeeded!"
}

fix_ownership(){
    if ! chown -R www-data:www-data "${WP_FILE_PATH}"; then
        echo "[FAIL] chown -R www-data:www-data ${WP_FILE_PATH}" >&2
        exit 1
    fi
}

main(){
    read_env
    validate_admin_credentials
    wait_for_db
    if ! wp core is-installed --path="${WP_FILE_PATH}" >/dev/null 2>&1; then
        install_wordpress
    fi
    fix_ownership
    echo "Starting PHP-FPM"
    exec php-fpm84 -F
}

main
