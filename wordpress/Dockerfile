FROM alpine:3.23

# https://wiki.alpinelinux.org/wiki/WordPress
RUN apk add --no-cache \
        bash \
        wget \
        php \
        php84-fpm \
        php84-json \
        php84-mysqli \
        php84-curl \
        php84-intl \
        php84-mbstring \
        php84-openssl \
        php84-xml \
        php84-zip \
        netcat-openbsd \
    && mkdir -p /var/www/html \
    && cd /var/www/html \
    && wget https://wordpress.org/latest.tar.gz \
    && tar -xzvf latest.tar.gz --strip-components=1 \
    && rm latest.tar.gz \
    && chown -R nobody:nobody /var/www/html \
    && sed -i 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/' /etc/php84/php-fpm.d/www.conf
    # vi /etc/php84/php-fpm.d/www.conf
    # re-write listen part.
    # in nginx.conf, fastcgi_pass should listen on the same port.

EXPOSE 9000

ENTRYPOINT ["entrypoint.sh"]
