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
    # && sed -i 's/memory_limit = '    
    && sed -i 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/' /etc/php84/php-fpm.d/www.conf

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY conf/.user.ini /etc/php84/conf.d/.user.ini
RUN  chmod +x /usr/local/bin/entrypoint.sh
#     # vi /etc/php84/php-fpm.d/www.conf
#     # re-write listen part.
#     # in nginx.conf, fastcgi_pass should listen on the same port.

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# ENTRYPOINT ["sh", "-c", "echo 'test'; exec tail -f /dev/null"]
