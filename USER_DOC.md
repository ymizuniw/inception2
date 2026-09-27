# User Documentation

This page is for anyone who just wants to **use** this WordPress site or
keep it running day to day — no Docker or code knowledge required. If
you're setting the project up or changing how it's built, see `DEV_DOC.md`
instead.

## What this is

This project runs a WordPress website. Behind the scenes it's made of three
small services working together:

| Service | What it does |
|---|---|
| **Website server** (nginx) | The only thing you actually talk to. Handles the secure (HTTPS) connection and hands requests to WordPress. |
| **WordPress** | The blog/website software itself — pages, posts, plugins, the admin panel. |
| **Database** (MariaDB) | Stores all of WordPress's content (posts, pages, users, settings). |

You don't need to interact with the database or the website server
directly — everything you'll do happens through the WordPress site itself.

## Starting and stopping the project

From the project's root folder, in a terminal:

```sh
make up      # start the website
make down    # stop the website
```

After `make up`, give it a few seconds — the database and WordPress need a
moment to be ready the very first time.

## Accessing the site

- **The website:** `https://<the project's domain name>/`
  (for example `https://ymizuniw.42.fr/`). Ask whoever set up the project
  for the exact domain if you don't know it.
- **The login page:** add `/wp-login.php` to that address, e.g.
  `https://ymizuniw.42.fr/wp-login.php` (or go to `/wp-admin` — it
  redirects there automatically if you're not logged in). There are two
  accounts: the administrator, and a second, regular (author) account —
  see below for both accounts' credentials.

> The site uses a self-signed security certificate, so your browser will
> show a warning ("connection not private" or similar) the first time.
> This is expected for this kind of project — proceed past the warning to
> reach the site.

## Finding and managing credentials

The admin username and password aren't written anywhere in this
documentation on purpose. They live in two places:

- **Admin username:** in the project's configuration file
  (`srcs/.env`, look for `WP_ADMIN_USER`).
- **Admin password:** in the project's secrets folder
  (`secrets/wp_admin_password.txt`) — a plain text file with just the
  password in it.
- **Second account's username:** `srcs/.env`, look for `WP_USER`.
- **Second account's password:** `secrets/wp_user_password.txt`.

If you need to change the admin password *after* the site has already been
set up, editing that file won't be enough (the site keeps its own copy).
Ask whoever manages the project to update it from inside WordPress (either
through the admin panel's "Users" page, or with one command they can run —
they'll know it as `wp user update`).

## Checking everything is running correctly

```sh
make logs
```

This shows what each service is doing, live. Press `Ctrl+C` to stop
watching (this does **not** stop the site).

A quick way to see the current status of each service:

```sh
docker compose -p inception -f srcs/docker-compose.yml ps
```

Everything is healthy when all three services show as **Up**, and the
website loads normally in a browser. If something looks wrong, or a
service isn't listed as "Up", pass this along to whoever manages the
project — the technical troubleshooting steps live in `DEV_DOC.md`.
