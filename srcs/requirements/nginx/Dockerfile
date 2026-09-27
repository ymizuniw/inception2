FROM alpine:3.23

RUN apk add nginx
COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]
