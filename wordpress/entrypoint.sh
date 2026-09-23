#!/bin/bash

wait_for_db(){
    for i in {30..0}
    do 
        if "$i" -eq 0; then
            echo "db timed out"
            exit 1
        fi
        if nc -z mariadb 3306; then
            echo "mariadb is working"
            break
        fi
    done
}

# // wp-config-sample.php
# define( 'DB_NAME', 'database_name_here' );
# define( 'DB_USER', 'username_here' );
# define( 'DB_PASSWORD', 'password_here' );
# define( 'DB_HOST', 'localhost' );

WP_CONFIG="/var/www/html/wp-config.php"

setup_wp_config(){
    sed -i "s/database_name_here/wordpress/" $WP_CONFIG
    sed -i "s/username_here/wpuser/"         $WP_CONFIG
    sed -i "s/password_here/wppassword/"     $WP_CONFIG
    sed -i "s/localhost/db/"                 $WP_CONFIG
}

main(){
    wait_for_db
    setup_wp_config
    exec php-fpm84 -F
}

main
