# Developer Documentation

For anyone setting up, building, or modifying this project. See
`README.md` for the architecture, and `USER_DOC.md` if you just want to
use the running site.

## 1. Prerequisites

### Docker

1. Install **Docker Engine + Docker Compose v2**, and confirm that Docker
   is installed:

   ```sh
   docker compose version
   ```

2. Execute `docker_init.sh`:

   ```sh
   chmod +x tools/docker_init.sh
   ./tools/docker_init.sh
   ```

### Secret setup

1. Create the secret data placeholders. This also calls the openssl API to
   generate the cert for SSL.

   ```sh
   chmod +x tools/configure_secrets.sh
   ./tools/configure_secrets.sh
   ```

2. Fill in:

   - `database_root_password.txt`
   - `database_user_password.txt`
   - `wp_admin_password.txt`
   - `wp_user_password.txt`

3. Set `127.0.0.1 ymizuniw.42.fr` in `/etc/hosts` to resolve the domain to
   `127.0.0.1`:

   ```sh
   echo "127.0.0.1 ymizuniw.42.fr" | sudo tee -a /etc/hosts
   ```

### Env setup

1. Copy the template:

   ```sh
   cp src/.env.template src/.env
   ```

2. Edit `src/.env` for your configuration.

## 2. Config files, per service

### `srcs/requirements/mariadb/conf/custom.cnf`

```ini
[mysqld]
bind-address = 0.0.0.0
```

Alpine's default MariaDB config only listens on the local Unix socket.
This file (copied to `/etc/my.cnf.d/99-custom.cnf`) makes it listen on the
network too, so the `wordpress` container can reach it over `wp_net`.

### `srcs/requirements/wordpress/conf/zz-custom.conf`

```ini
[www]
listen = 9000
user = www-data
group = www-data
```

PHP-FPM pool override (copied to `/etc/php84/php-fpm.d/zz-custom.conf`).
`listen = 9000` binds on all interfaces so `nginx` can reach it over
`wp_net`. php-fpm runs as the `www-data` user and group.

### `srcs/requirements/nginx/conf/nginx.conf`

The whole nginx config: one `server` block, TLS-only.

- `listen 443 ssl;` + `ssl_protocols TLSv1.2 TLSv1.3;` with
  `ssl_certificate`/`ssl_certificate_key` pointing at the mounted secrets
- `root /var/www/html/;` + `index index.php;` — the `index` line matters:
  without it, a bare `/` request matches the directory itself and nginx
  returns `403` before ever reaching the `try_files` fallback.
- `location /` — `try_files $uri $uri/ /index.php$is_args$args;` (serves
  static files directly, hands everything else to WordPress).
- `location ~ \.php$` — proxies to `wordpress_container:9000` over
  FastCGI (`upstream wp_fastcgi_passes`).

### `srcs/requirements/wordpress/conf/.user.ini`

```ini
memory_limit=256M
```

Raises PHP's per-request memory limit above Alpine's default (128M),
since WordPress admin operations (plugin updates, media handling) can
exceed that.

## 3. Build and launch

```sh
make up      # build (if needed) and start everything, detached
make logs    # follow every container's logs
make down    # stop and remove the containers (keeps data)
make re      # rebuild all images from scratch, then start
```

These wrap `docker compose -p inception -f srcs/docker-compose.yml <cmd>`.

## 4. Useful `docker` commands

```sh
docker exec -it container_name
docker logs container_name
```

## 5. Confirm that the database doesn't lose its contents

```sh
docker exec mariadb_container mariadb -u root -e "SHOW TABLES;" wordpress
```
