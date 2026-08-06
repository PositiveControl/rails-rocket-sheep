# Deployment

Kamal 2 from a fresh VPS to a running app. The template writes the config; this is what you fill in and run.

---

## What the template sets up

- `config/deploy.yml` — Kamal 2 with a PostgreSQL accessory
- `Dockerfile` — multi-stage production build
- `bin/docker-entrypoint` — runs `db:prepare` before the server starts
- `.kamal/secrets` — secret scaffold, gitignored

The four Solid Stack databases (primary, queue, cable, cache) all live in the same PostgreSQL instance by default, separated by database name. That's the right call until one of them becomes a bottleneck — see [Extracting the database](#extracting-the-database) below.

---

## Prerequisites

- A server with a public IP. Any Ubuntu/Debian VPS works — Hetzner, DigitalOcean, Vultr.
- A domain pointed at that IP with an A record.
- A Docker registry. Docker Hub or `ghcr.io` both work.
- SSH key access to the server as root, or a user with Docker permissions.

Kamal installs Docker on the server itself during `kamal setup`. You don't need to prepare it.

---

## Configure

### 1. `config/deploy.yml`

```yaml
service: myapp
image: yourusername/myapp

servers:
  web:
    hosts:
      - 203.0.113.10          # your server IP
    options:
      memory: 2g
      add-host: host.docker.internal:host-gateway

proxy:
  ssl: true
  host: myapp.com             # your domain
  app_port: 3000
  healthcheck:
    path: /up
    interval: 3
    timeout: 3

registry:
  username: yourusername
  password:
    - KAMAL_REGISTRY_PASSWORD
```

`ssl: true` makes kamal-proxy provision a Let's Encrypt certificate automatically. DNS must already resolve to the server or the challenge fails.

The `/up` health check route is created by the template.

### 2. `.kamal/secrets`

Never commit this — the template gitignores it.

```bash
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
RAILS_MASTER_KEY=$(cat config/master.key)
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DATABASE_URL=$DATABASE_URL
QUEUE_DATABASE_URL=$QUEUE_DATABASE_URL
CABLE_DATABASE_URL=$CABLE_DATABASE_URL
CACHE_DATABASE_URL=$CACHE_DATABASE_URL
```

Values come from your shell environment. Use direnv, 1Password's CLI, or plain exports — Kamal reads whatever the shell provides.

The four `*_DATABASE_URL` variables can all point at the same PostgreSQL host with different database names. `config/database.yml` falls back to `DATABASE_URL` for any that are unset.

### 3. Non-obvious placeholders

Easy to miss because nothing breaks locally:

- `public/robots.txt` — the `Sitemap:` line still says `example.com`
- `.github/workflows/lighthouse.yml` — the production URL to audit
- `app/lib/app_config.rb` — `BRANDING` name, tagline, support email

---

## Deploy

```bash
kamal setup     # first time: installs Docker, starts accessories, deploys
kamal deploy    # every time after
```

`kamal setup` takes several minutes. It installs Docker, pulls and starts the PostgreSQL accessory, builds and pushes your image, then boots the app.

### Useful commands

```bash
kamal app logs -f            # tail logs
kamal app exec --interactive "bin/rails console"
kamal app exec "bin/rails db:migrate"
kamal rollback               # previous version
kamal accessory logs db -f   # PostgreSQL logs
kamal proxy logs -f          # kamal-proxy / TLS issues
```

---

## Running Solid Queue

Solid Queue needs a worker process. The simplest approach is a second role in `config/deploy.yml` on the same host:

```yaml
servers:
  web:
    hosts:
      - 203.0.113.10
  job:
    hosts:
      - 203.0.113.10
    cmd: bin/jobs
```

`bin/jobs` ships with Rails 8. Scale worker processes per host with the `JOB_CONCURRENCY` environment variable, which `config/queue.yml` reads.

For a low-traffic app you can instead run Solid Queue inside Puma by setting `SOLID_QUEUE_IN_PUMA=true`, which avoids a second container entirely. Fine until job volume grows enough that jobs start competing with web requests.

---

## After the first deploy

`kamal setup` leaves a server with SSH open to the world and no firewall. Harden it before you have real users — see the generated `docs/how-tos/harden-a-kamal-server.md`, which covers UFW rules, disabling password auth, restricting SSH, and enabling unattended upgrades.

Two things worth doing on day one:

1. **Backups.** The PostgreSQL accessory writes to a Docker volume. Nothing backs it up. Set up `pg_dump` to object storage on a cron, and *test a restore* — an untested backup isn't a backup.
2. **Uptime monitoring.** An external check against `/up`. Any free tier is fine. Without it you find out about downtime from users.

---

## Extracting the database

Running PostgreSQL on the same box as the app is correct for a small app and wrong for a growing one — a deploy that exhausts memory takes the database with it.

The generated `docs/how-tos/extract-database-and-storage.md` covers moving PostgreSQL to a managed provider or a separate VPS, and moving Active Storage off local disk. The short version: change the `*_DATABASE_URL` secrets, remove the accessory from `deploy.yml`, and redeploy. Because everything routes through those environment variables, nothing in the application code changes.

---

## Troubleshooting

**TLS certificate won't issue.** DNS isn't resolving to the server yet, or ports 80/443 are blocked. Let's Encrypt needs port 80 reachable for the challenge. Check with `kamal proxy logs`.

**`db:prepare` fails on first deploy.** The PostgreSQL accessory isn't up yet, or `POSTGRES_PASSWORD` doesn't match what the accessory was created with. Passwords are baked in at accessory creation — changing the secret later requires recreating the accessory.

**Assets missing after deploy.** The Dockerfile precompiles during build, which requires `RAILS_MASTER_KEY` at build time. Confirm it's exported in your shell.

**Deploy succeeds, health check fails.** The app is booting but erroring. `kamal app logs` shows the real cause — usually a missing environment variable that exists locally but was never added to `.kamal/secrets`.
