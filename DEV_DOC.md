# Developer Documentation

For anyone setting up, building, or modifying this project. See
`README.md` for the architecture, and `USER_DOC.md` if you just want to
use the running site.

## 1. Prerequisites

- **Docker Engine + Docker Compose v2** (`docker compose version`). Not
  preinstalled on a stock Debian/Ubuntu VM — install it from Docker's own
  apt repository, not the distro's `docker.io` package
  ([official docs](https://docs.docker.com/engine/install/debian/)):
  ```sh
  # Docker's GPG key + apt repo
  sudo apt update
  sudo apt install ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
  Types: deb
  URIs: https://download.docker.com/linux/debian
  Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
  Components: stable
  Architectures: $(dpkg --print-architecture)
  Signed-By: /etc/apt/keyrings/docker.asc
  EOF
  sudo apt update

  # Install + verify
  sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
  sudo docker run hello-world
  ```
- `openssl` (to generate the TLS certificate via `gen_cert.sh`).
- A domain resolving to `127.0.0.1` on the host, per the 42 subject:
  ```sh
  echo "127.0.0.1 ymizuniw.42.fr" | sudo tee -a /etc/hosts
  ```
- `srcs/.env` and `secrets/` present at the repository root (both
  git-ignored — create them yourself on a fresh clone; not covered here).
- The two host directories `.env`'s `DATA_PATH` points at
  (`${DATA_PATH}/db-data`, `${DATA_PATH}/html`) must exist *before* the
  first `up` — the named volumes below are bind-backed to a fixed host
  path, so unlike a plain bind mount Docker won't create it for you.
  `make up`/`make re` already do this (`mkdir -p`), so it's automatic as
  long as you go through the Makefile.

## 2. Config files, per service

### `srcs/requirements/mariadb/conf/custom.cnf`

```ini
[mysqld]
bind-address = 0.0.0.0
```

Alpine's default MariaDB config only listens on the local Unix socket.
This file (copied to `/etc/my.cnf.d/99-custom.cnf`) makes it listen on the
network too, so the `wordpress` container can reach it over `wp_net`.

### `srcs/requirements/nginx/conf/nginx.conf`

The whole nginx config: one `server` block, TLS-only.

- `listen 443 ssl;` + `ssl_protocols TLSv1.2 TLSv1.3;` with
  `ssl_certificate`/`ssl_certificate_key` pointing at the mounted secrets
  — no plaintext listener.
- `root /var/www/html/;` + `index index.php;` — the `index` line matters:
  without it, a bare `/` request matches the directory itself and nginx
  returns `403` before ever reaching the `try_files` fallback.
- `location /` — `try_files $uri $uri/ /index.php$is_args$args;` (serves
  static files directly, hands everything else to WordPress).
- `location ~ \.php$` — proxies to `wordpress_container:9000` over
  FastCGI (`upstream wp_fastcgi_passes`).

### `gen_cert.sh` (generates nginx's TLS material)

Run on the host (the VM), not inside any container — it just needs
`openssl`, and its output has to exist in `secrets/` before `nginx` is
even built.

```sh
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 3650 -signkey server.key -in server.csr -out server.crt
```

Three steps, each consuming the previous one's output:

1. `genrsa` — generates a 2048-bit RSA private key, `server.key`.
2. `req -new` — creates a Certificate Signing Request (`server.csr`) from
   that key, prompting for the certificate's subject fields (the `CN`
   should match `DOMAIN_NAME`).
3. `x509 -req -signkey ... -in server.csr` — instead of sending the CSR to
   a real CA, self-signs it with the same private key, producing
   `server.crt` (valid for 3650 days).

The result — `server.key`/`server.crt` (plus the intermediate `server.csr`,
kept only for reference) — lands in `secrets/` and is mounted into
`nginx_container` as the `nginx_ssl_key`/`nginx_ssl_crt`/`nginx_ssl_csr`
secrets (see `nginx.conf`'s `ssl_certificate`/`ssl_certificate_key`).

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
# rebuild + restart one service after editing its Dockerfile/entrypoint/conf
docker compose -p inception -f srcs/docker-compose.yml up -d --build <service>

# status of all three containers
docker compose -p inception -f srcs/docker-compose.yml ps

# validate the compose file without starting anything
docker compose -p inception -f srcs/docker-compose.yml config -q

# tail one container's logs
docker compose -p inception -f srcs/docker-compose.yml logs -f <service>

# shell into a container / run a one-off command
docker exec -it wordpress_container sh
docker exec wordpress_container wp option get siteurl --path=/var/www/html
```

## 5. Confirm a restart doesn't alter data

Both volumes are Docker named volumes (declared under `volumes:` and
referenced by name in each service — see `README.md`'s "Docker Volumes vs
Bind Mounts" note for why they're backed by a fixed host path via
`driver_opts` rather than a plain bind mount), so a restart should leave
everything exactly as it was:

```sh
docker exec wordpress_container wp post list --path=/var/www/html --field=ID  # note the output

make down
make up

docker exec wordpress_container wp post list --path=/var/www/html --field=ID  # same output
```

If the second list matches the first, WordPress's content survived the
restart untouched. The same check works for the database directly:

```sh
docker exec mariadb_container mariadb -u root -e "SHOW TABLES;" wordpress
```
