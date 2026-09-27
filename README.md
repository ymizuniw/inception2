*This project has been created as part of the 42 curriculum by ymizuniw.*

# Inception

## Description

Inception is a 42 system-administration project: build a small, self-hosted
web infrastructure entirely out of Docker containers, each running its own
service, orchestrated by a single Docker Compose file and driven by one
`Makefile`.

The stack has three containers, one per service, each built from its own
Dockerfile (no pre-built service images, no `latest` tags):

| Container  | Role                                              |
|------------|---------------------------------------------------|
| `mariadb`  | The WordPress database.                            |
| `wordpress`| WordPress + PHP-FPM, with no built-in webserver.    |
| `nginx`    | The only entrypoint, terminating TLS on port 443.  |

They talk to each other over a single dedicated bridge network (`wp_net`),
persist data through two host-backed volumes (`db-data`, `html`), and never
hardcode credentials: every password is injected as a Docker secret (a file
under `secrets/`, never committed to git) or through an `.env` file that is
also excluded from version control.

Goals this project is meant to demonstrate: multi-container orchestration
with Compose, one process per container, TLS-only access, secrets handled
outside the image and outside git, and reproducible startup through
`docker-compose.yml` and idempotent entrypoint scripts.

### Design choices

**Virtual Machines vs Docker.** A VM virtualizes hardware through a
hypervisor; Docker's `dockerd` daemon runs containers directly on the
host's kernel, so they start and stop in about a second instead of
minutes. Each service here builds from a minimal Alpine image, so it
reproduces identically on any machine that can run Docker. Containers are
also isolated from each other — `wp_net` keeps them off the host network,
and each is given only the secrets it needs (e.g. `wp_admin_password`
never reaches `nginx_container`).

**Secrets vs Environment Variables.** Values that alone can authenticate
— passwords, the TLS key — go through Docker secrets, mounted read-only at
`/run/secrets/` only into the containers that declare them. Values that
are just identifiers (usernames, hostnames, the domain) go through
`.env`, since knowing them alone grants no access. Neither `secrets/` nor
`.env` is committed to git.

**Docker Network vs Host Network.** All three containers share one named
bridge network, `wp_net`, where each reaches the others by container name
via Docker's built-in DNS. `network_mode: host` would drop that isolation
and expose whatever a container binds directly on the host's real
interfaces. With `wp_net`, only `nginx`'s `443` is published; MariaDB and
WordPress have no `ports:` at all.

**Docker Volumes vs Bind Mounts.** `db-data` and `html` are actually a
hybrid: named volumes in `docker-compose.yml` (`html:/var/www/html`,
managed by Docker like any volume), but with `driver_opts: {type: none,
o: bind, device: ...}` pointing each one at a specific host path. That
gets Docker's simple volume syntax and lifecycle management, while still
landing on a predictable, inspectable host directory — useful since a
pure bind mount scattered across arbitrary host paths gets costly to
reason about (and slow, if `dockerd` runs inside a VM without a shared
filesystem to the host) once you need to find or back up the data.

## Architecture

```
                         host:443
                             │
                    ┌────────▼────────┐
                    │  nginx_container │  TLS termination (443 only)
                    │  (Alpine, nginx) │  serves /var/www/html (static)
                    └────────┬────────┘  proxies *.php over FastCGI
                             │ :9000 (wp_net)
                    ┌────────▼─────────┐
                    │ wordpress_container│ PHP-FPM 8.4, no webserver
                    │  (Alpine, php-fpm) │ WordPress core in /var/www/html
                    └────────┬─────────┘
                             │ :3306 (wp_net)
                    ┌────────▼────────┐
                    │ mariadb_container│  the WordPress database
                    │   (Alpine, mariadb)
                    └─────────────────┘

Network: wp_net (bridge, one per stack)
Volumes (host bind mounts):
  html     ⇄ ${DATA_PATH}/html     (shared between wordpress and nginx)
  db-data  ⇄ ${DATA_PATH}/db-data  (mariadb only)
```

Only nginx is reachable from the host. WordPress talks to MariaDB only
over the internal `wp_net` network; there is no exposed database port.

## Instructions

### Prerequisites

- Docker Engine and Docker Compose v2 (`docker compose version`).
- A domain name resolving to `127.0.0.1` on the host, per the subject
  (`<login>.42.fr`). Add it to `/etc/hosts`:
  ```sh
  echo "127.0.0.1 ymizuniw.42.fr" | sudo tee -a /etc/hosts
  ```
- `openssl`, to generate the self-signed TLS certificate used by nginx.

### Setup

1. **Secrets.** Create `secrets/` at the repository root with one file per
   secret (root DB password, WordPress DB user password, WP admin password,
   and the TLS key/cert/csr). `gen_cert.sh` generates the certificate:
   ```sh
   ./gen_cert.sh
   ```
   The other password files are plain text files containing a single line —
   create them by hand, e.g. `echo "a_strong_password" > secrets/wp_admin_password.txt`.

2. **Environment.** Copy/edit `srcs/.env` with the project's configuration
   (domain name, data path, database name/user, WordPress admin username,
   etc.). Neither `srcs/.env` nor `secrets/` are tracked by git
   (see `.gitignore`).

3. **Build and run**, from the repository root:
   ```sh
   make up      # docker compose -p inception -f srcs/docker-compose.yml up -d
   make logs    # follow container logs
   make down    # stop and remove the containers
   make re      # rebuild from scratch and restart
   ```

4. **Visit** `https://<DOMAIN_NAME>/` (e.g. `https://ymizuniw.42.fr/`). The
   certificate is self-signed, so the browser will warn before letting you
   through.

### Directory layout

```
.
├── Makefile
├── gen_cert.sh
├── secrets/                     # git-ignored: passwords + TLS material
└── srcs/
    ├── .env                     # git-ignored: per-deployment configuration
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/    (Dockerfile, entrypoint.sh, conf/custom.cnf)
        ├── nginx/      (Dockerfile, conf/nginx.conf)
        └── wordpress/  (Dockerfile, entrypoint.sh, conf/.user.ini)
```

### Notes on the design

- **Idempotent entrypoints.** Both `mariadb/entrypoint.sh` and
  `wordpress/entrypoint.sh` check whether their data directory (`/var/lib/mysql`,
  `/var/www/html`) is already initialized before doing anything destructive,
  so restarting a container never re-runs `mariadb-install-db` or
  `wp core install` against data that is already there.
- **Persistence.** `db-data` and `html` are bind-mounted from the host
  (`${DATA_PATH}/db-data`, `${DATA_PATH}/html`), so container recreation
  never loses data.
- **TLS only.** nginx listens on 443 only, with `ssl_protocols TLSv1.2
  TLSv1.3`; there is no plaintext HTTP listener.

## Resources

### References

- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Alpine Linux — WordPress on Alpine](https://wiki.alpinelinux.org/wiki/WordPress)
- [MariaDB — mariadb-install-db](https://mariadb.com/kb/en/mysql_install_db/) and
  [mysqld --bootstrap](https://mariadb.com/kb/en/mysqld-options/#-bootstrap)
- [nginx — `try_files`](https://nginx.org/en/docs/http/ngx_http_core_module.html#try_files)
  and [FastCGI with PHP-FPM](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/)
- [WP-CLI command reference](https://developer.wordpress.org/cli/commands/)
- [OpenSSL — self-signed certificates](https://docs.openssl.org/master/man1/openssl-req/)

### AI usage

Claude Code (Anthropic) was used throughout this project as a pair-programming
and debugging assistant, always applied to code the author reviewed and
tested before keeping:

- **Debugging container startup failures** by reading `docker compose logs`
  output and pointing to the exact cause (e.g. MariaDB not listening on TCP
  because Alpine's default config sets `skip-networking`; the WordPress
  container missing the `mariadb-client` package; a `wp core is-installed`
  check run without `--path`, so it always looked in the wrong directory).
- **Reviewing the entrypoint scripts** (`mariadb/entrypoint.sh`,
  `wordpress/entrypoint.sh`) for correctness and idempotency — e.g. flagging
  that `wp core download`/`wp config create` fail on a second run unless
  `--force` is used, once a previous run had partially completed.
- **Reviewing the nginx configuration**, explaining why a bare `location /`
  with `try_files` and no `index` directive returns `403 Forbidden` instead
  of falling through to `index.php`, and why validating an `upstream` block
  by hostname at build time (`nginx -t`/`-T` in a `RUN` step) fails, since
  that hostname doesn't exist on the Docker network yet during the build.
- **Restructuring the repository** into the `secrets/` + `srcs/requirements/`
  layout used above, updating `docker-compose.yml` build contexts and
  secret paths, and the `Makefile`, to match.
- **Drafting this README** from the project's actual files and configuration,
  which the author then edited.

All infrastructure decisions (which services to containerize, network and
volume layout, secret handling, TLS setup) and all final code were made and
verified by the author; AI-suggested fixes were tested against the running
containers before being kept.
