#!/bin/bash

cleanup(){
    rm -fr /var/lib/mysql /run/mysqld
    apk del mariadb mariadb-client
    echo "package may left"
    exit 1
}

set_ownership(){
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
        && chown -R mysql /var/lib/mysql/data
    fi
    mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
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
    echo "MariaDB test daemon stopped. Restarting daemon..."
    exec mariadbd --user=mysql
}

main
