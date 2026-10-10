FROM alpine:3.23

# # https://wiki.alpinelinux.org/wiki/WordPress
RUN apk add --no-cache \
        bash curl mariadb-client\
        php84 \
        php84-phar \
        php84-fpm \
        php84-json \
        php84-mysqli \
        php84-curl \
        php84-intl \
        php84-mbstring \
        php84-openssl \
        php84-xml \
        php84-zip \
		php84-exif \
		php84-gd \
    && sed -i 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/' /etc/php84/php-fpm.d/www.conf

# www-data (UID/GID 82) runs the php-fpm workers; fixed so a later FTP container can match it.
# The base image may already have the group, so each step is skipped if it exists.
#   addgroup -g 82   set GID 82
#   addgroup -S      system group
#   adduser  -u 82   set UID 82
#   adduser  -S      system user (no password, nologin shell)
#   adduser  -D      don't assign a password (no interactive prompt)
#   adduser  -G      primary group: www-data
#   adduser  -H      don't create a home directory
RUN (getent group www-data >/dev/null || addgroup -g 82 -S www-data) \
    && (id www-data >/dev/null 2>&1 || adduser -u 82 -S -D -G www-data -H www-data) \
    && id www-data

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY conf/99-custom.ini /etc/php84/conf.d/99-custom.ini
COPY conf/zz-custom.conf /etc/php84/php-fpm.d/zz-custom.conf

RUN  chmod +x /usr/local/bin/entrypoint.sh
#     # vi /etc/php84/php-fpm.d/www.conf
#     # re-write listen part.
#     # in nginx.conf, fastcgi_pass should listen on the same port.

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
