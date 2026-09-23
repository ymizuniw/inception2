FROM alpine:3.23
RUN apk add nginx
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY certs/ /etc/nginx/certs/

CMD ["nginx", "-g", "daemon off;"]
