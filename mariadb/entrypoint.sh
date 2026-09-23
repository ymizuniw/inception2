#!/bin/bash

cleanup(){
    rm -fr /var/lib/mysql /run/mysqld
    apk del mariadb mariadb-client
    if [ $(cat mariadbd) ]; then
        echo "package left"
    fi
    exit 1
}

set_ownership(){
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql
        mkdir /var/lib/mysql/data && chown -R mysql /var/lib/mysql/data
    fi
    mkdir /run/mysqld && chown mysql:mysql /run/mysqld
}

db_daemon_check(){
    mariadbd-safe --user=mysql &
    MARIADB_PID=$!

    for i in {30..0}
    do
        if [ $i -eq 0 ]; then
            echo "mariadbd timed out"
            kill $MARIADB_PID 2>/dev/null
            cleanup
        fi
	
	if ! kill -0 $MARIADB_PID 2>/dev/null; then
		echo "mariadbd process died unexpectedly"
       		cleanup
            	exit 1
        fi
        if mariadb -u root -e "SELECT 1;" 2>/dev/null; then
            echo "MariaDB waked up."
            break
        fi
        sleep 1
    done

    kill $MARIADB_PID
    wait $MARIADB_PID 2>/dev/null
    echo "MariaDB test daemon stopped. Restarting daemon..."
}

main(){
    set_ownership
    db_daemon_check
    exec mariadbd --user=mysql
}

main
