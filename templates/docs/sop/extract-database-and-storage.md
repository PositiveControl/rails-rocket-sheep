# Plan: Extract Database and File Storage to External Services

> **Written for PostgreSQL.** On MySQL or MariaDB the shape is identical —
> provision, dump, restore, repoint `DATABASE_URL`, drop the accessory — but the
> tools, the port, and the URL scheme differ. The substitutions are in
> [MySQL and MariaDB equivalents](#mysql-and-mariadb-equivalents) at the end;
> everything else on this page applies unchanged. Which database this app runs is
> on the Tech Stack line of `CLAUDE.md`.

## Goal

Make the app server stateless by moving the database and file storage to external
services. This enables horizontal scaling, zero-downtime server replacement, and simpler disaster recovery.

## Current State

- **PostgreSQL:** Runs as a Kamal accessory (Docker container) on the same server as the app
- **File storage:** Active Storage with `:local` disk service, mounted via Docker volume (`myapp_storage:/rails/storage`)
- **Firewall:** DOCKER-USER iptables rules block external access to ports 80, 443, 5432 (scoped to `-i eth0`)

## Target State

- **PostgreSQL:** Managed database service (e.g., Neon, Supabase, Hetzner managed DB, or a dedicated Hetzner server)
- **File storage:** Cloudflare R2 (S3-compatible, no egress fees, pairs well with existing Cloudflare setup)
- **App server:** Fully stateless — can be destroyed and recreated with `kamal setup && kamal deploy`

## Recommended Services

### Database: Neon or Supabase (PostgreSQL)

| Option | Pros | Cons |
|--------|------|------|
| **Neon** | Serverless scaling, branching for dev/staging, generous free tier | Newer service |
| **Supabase** | Full Postgres, built-in auth/storage (unused), good free tier | More than we need |
| **Hetzner Managed DB** | Same provider, low latency, simple | No free tier, less flexible |
| **Separate Hetzner VPS** | Cheapest at scale, full control | Must manage backups, updates, replication yourself |

### File Storage: Cloudflare R2

- S3-compatible API (drop-in for Active Storage)
- Zero egress fees (critical for serving user uploads)
- Already using Cloudflare for CDN — natural pairing
- Custom domain support via Cloudflare (e.g., `media.myapp.com`)

## Migration Steps

### Phase 1: Database Migration

#### 1.1 Provision external database

Choose provider and create a PostgreSQL 16 database. Note the connection string.

#### 1.2 Restrict access

On the DB provider side, whitelist only the app server IP (`203.0.113.10`). Enable SSL/TLS for the connection.

#### 1.3 Migrate data

```bash
# Dump from current database
kamal app exec "pg_dump -Fc -h <db-accessory-ip> -U myapp myapp_production > /tmp/db.dump"

# Copy dump to local machine
kamal app exec "cat /tmp/db.dump" > db.dump

# Restore to new database
pg_restore -h <new-host> -U <user> -d <dbname> --no-owner --no-privileges db.dump
```

#### 1.4 Update deploy.yml

```yaml
# Remove the db accessory entirely
# accessories:
#   db:
#     ...

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL          # Now points to external host
    - QUEUE_DATABASE_URL    # Same external host, different database
    - CABLE_DATABASE_URL    # Same external host, different database
    - CACHE_DATABASE_URL    # Same external host, different database
```

Update `.kamal/secrets`:

```bash
DATABASE_URL=postgres://user:password@host:5432/myapp_production?sslmode=require
QUEUE_DATABASE_URL=postgres://user:password@host:5432/myapp_queue_production?sslmode=require
CABLE_DATABASE_URL=postgres://user:password@host:5432/myapp_cable_production?sslmode=require
CACHE_DATABASE_URL=postgres://user:password@host:5432/myapp_cache_production?sslmode=require
```

#### 1.5 Update firewall

On the app server:

```bash
# Remove PostgreSQL iptables rule (no local PG to protect)
iptables -D DOCKER-USER -i eth0 -p tcp --dport 5432 -j DROP

# Remove ufw PostgreSQL rule
ufw delete deny 5432

# Save
netfilter-persistent save
```

No new rules needed — outbound from Docker to the external DB already works with `-i eth0` scoping.

#### 1.6 Deploy and verify

```bash
kamal deploy
kamal app exec "bin/rails db:migrate"
kamal app exec "bin/rails runner 'puts User.count'"
```

#### 1.7 Decommission old database

```bash
# After confirming everything works
kamal accessory remove db
```

### Phase 2: File Storage Migration

#### 2.1 Set up Cloudflare R2

1. Create an R2 bucket in the Cloudflare dashboard (e.g., `myapp-production`)
2. Generate an API token with R2 read/write access
3. Note the account ID, access key ID, and secret access key
4. Optionally set up a custom domain: `media.myapp.com`

#### 2.2 Add the aws-sdk-s3 gem

```ruby
# Gemfile
gem "aws-sdk-s3", require: false
```

#### 2.3 Configure Active Storage

```yaml
# config/storage.yml
cloudflare:
  service: S3
  endpoint: https://<account-id>.r2.cloudflarestorage.com
  access_key_id: <%= Rails.application.credentials.dig(:cloudflare, :r2_access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:cloudflare, :r2_secret_access_key) %>
  region: auto
  bucket: myapp-production
  public: true
```

#### 2.4 Update production config

```ruby
# config/environments/production.rb
config.active_storage.service = :cloudflare
```

#### 2.5 Migrate existing files

```ruby
# lib/tasks/storage.rake
namespace :storage do
  desc "Migrate local files to Cloudflare R2"
  task migrate_to_r2: :environment do
    ActiveStorage::Blob.where(service_name: "local").find_each do |blob|
      print "."
      local_path = ActiveStorage::Blob.service.path_for(blob.key)
      next unless File.exist?(local_path)

      # Upload to R2
      blob.open do |file|
        ActiveStorage::Blob.service.upload(blob.key, file, checksum: blob.checksum)
      end

      blob.update_column(:service_name, "cloudflare")
    end
    puts "\nDone!"
  end
end
```

#### 2.6 Update deploy.yml

```yaml
# Remove the storage volume
# volumes:
#   - "myapp_storage:/rails/storage"

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    # ... other DB URLs
    - CLOUDFLARE_R2_ACCESS_KEY_ID
    - CLOUDFLARE_R2_SECRET_ACCESS_KEY
```

#### 2.7 Deploy and verify

```bash
kamal deploy
# Verify uploads work and existing files are served
```

### Phase 3: Verify Statelessness

After both migrations, confirm the server is stateless:

```bash
# No local data dependencies
docker volume ls  # Should show no app-specific volumes

# Can redeploy from scratch
kamal app boot

# Health check passes
curl -I https://myapp.com/up
```

## Rollback Plan

### Database

Keep the Kamal db accessory running (don't remove it) until the external DB is verified for at least 48 hours. If issues arise, revert `DATABASE_URL` to the local connection string and redeploy.

### File Storage

Use Active Storage's Mirror service during migration to write to both local and R2 simultaneously:

```yaml
# config/storage.yml (during migration)
mirror:
  service: Mirror
  primary: cloudflare
  mirrors: [ local ]
```

Once verified, switch to `cloudflare` only and remove the volume.

## Firewall Changes Summary

| Rule | Current | After Extraction |
|------|---------|-----------------|
| DOCKER-USER: drop 5432 on eth0 | Yes | Remove (no local PG) |
| UFW: deny 5432 | Yes | Remove |
| DOCKER-USER: drop 80,443 on eth0 | Yes | Keep (still need Cloudflare-only access) |
| DOCKER-USER: allow Cloudflare IPs | Yes | Keep |
| UFW: allow Cloudflare IPs | Yes | Keep |
| DB provider: whitelist app server IP | N/A | Add (on provider side) |

## Estimated Effort

| Phase | Effort | Downtime |
|-------|--------|----------|
| Database migration | 2-3 hours | ~5 min (DNS/connection switch) |
| File storage migration | 2-3 hours | Zero (Mirror service bridges the gap) |
| Verification & cleanup | 1 hour | Zero |

## MySQL and MariaDB equivalents

Substitute these; the phases, the firewall changes, and the storage half are the
same.

| PostgreSQL | MySQL / MariaDB |
|---|---|
| `pg_dump -Fc -h HOST -U USER DB > db.dump` | `mysqldump --single-transaction --routines --triggers -h HOST -u USER -p DB > db.sql` |
| `pg_restore -h HOST -U USER -d DB --no-owner --no-privileges db.dump` | `mysql -h HOST -u USER -p DB < db.sql` |
| `postgres://user:pass@host:5432/db?sslmode=require` | `mysql2://user:pass@host:3306/db?ssl_mode=required` — or `trilogy://` if this app uses the trilogy adapter |
| port `5432` in every firewall rule | port `3306` |
| `postgresql-client` in the Dockerfile | `default-mysql-client` (already there) |
| Neon, Supabase | PlanetScale, Aiven, DigitalOcean Managed MySQL, Hetzner managed |

Two differences worth planning for rather than discovering:

- **`--single-transaction` only gives you a consistent dump on InnoDB.** Any
  MyISAM table needs a read lock or a maintenance window.
- **Managed MySQL providers vary on whether they allow four databases per
  instance.** The Solid Stack wants `primary`, `queue`, `cable`, and `cache`;
  check the plan's database limit before committing to a provider.

## Applies To

This plan applies to any Kamal-deployed Rails app using the Rocket Sheep template. The steps are generic — only connection strings and bucket names change per app.
