#!/bin/bash

cleanup(){
    rm -fr /var/lib/mysql /run/mysqld
    apk del mariadb mariadb-client
    echo "package may left"
    exit 1
}

set_ownership(){
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    fi
    chown -R mysql:mysql /var/lib/mysql/mysql
    mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
}

init_db(){
    mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY 'wppassword';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
EOF
}

db_daemon_check(){
    mariadbd --user=mysql &
    MARIADB_PID=$!

    for i in {30..0}
    do
        if [ "$i" -eq 0 ]; then
            echo "mariadbd timed out"
            kill $MARIADB_PID 2>/dev/null
            cleanup
        fi
	
        if ! kill -0 $MARIADB_PID 2>/dev/null; then
            echo "mariadbd process died unexpectedly"
            cleanup
        fi

        if mariadb -u root -e "SELECT 1;" 2>/dev/null; then
            echo "MariaDB waked up."
            init_db
            break
        fi
        sleep 1
    done

    echo "stopping daemon..."
    kill "$MARIADB_PID"
    wait "$MARIADB_PID" 2>/dev/null
}

main(){
    echo "Hello, this is mariadb entrypoint"
    set_ownership
    db_daemon_check
    init_db

    echo "MariaDB test daemon stopped. Restarting daemon..."
    exec mariadbd --user=mysql
}

main
