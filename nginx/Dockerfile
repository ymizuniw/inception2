FROM alpine:3.23
RUN apk add nginx
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY certs/ /etc/nginx/certs/
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
