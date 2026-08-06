# What's Included

Every gem and file the template adds, and the reason it's there. Nothing here is a dependency you can't remove — it's all plain Rails files you own.

---

## Gems added

Rails 8 already ships Solid Queue, Solid Cache, Solid Cable, Kamal, and Thruster, so the template doesn't re-add them. It removes `sqlite3` (this is a PostgreSQL template) and adds:

| Gem | Group | Why |
|---|---|---|
| `tailwindcss-rails` | — | Styling, no bundler needed |
| `devise` | — | Authentication, pre-configured for Turbo |
| `petergate` | — | Role-based authorization on top of Devise |
| `discard` | — | Soft deletes without hand-rolling `deleted_at` scopes |
| `paper_trail` | — | Audit trail, installed `--with-changes` |
| `pagy` | — | Pagination; far lighter than Kaminari |
| `slim-rails` | — | Terser templates, enforced indentation |
| `resend` | — | Transactional email API client |
| `letter_opener_web` | development | Preview mail at `/letter_opener` |
| `pry`, `pry-rails` | dev, test | `binding.pry` debugging |
| `bullet` | dev, test | N+1 query detection |
| `rubocop-rails-omakase` | dev, test | Linting, DHH's config |
| `brakeman` | dev, test | Security static analysis |
| `vcr`, `webmock` | test | Record and replay HTTP in tests |

---

## Files the template writes

### Configuration

| File | Purpose |
|---|---|
| `config/database.yml` | Multi-database setup — primary, queue, cable, cache — with per-environment names and `migrations_paths` |
| `config/queue.yml` | Solid Queue dispatchers and workers; production tuned separately |
| `config/cache.yml` | Solid Cache retention and size caps; connects to the `cache` database in production |
| `config/cable.yml` | Solid Cable in development *and* production, so behaviour matches |
| `config/recurring.yml` | Recurring job schedule scaffold |
| `config/deploy.yml` | Kamal 2 with a PostgreSQL accessory |
| `config/routes.rb` | Health check, sitemap, letter_opener mount, root |
| `.rubocop.yml` | Rails Omakase base |

`config/application.rb` is modified to set UUID primary keys on the generators and to autoload `app/lib`.

> **Note:** the four Solid Stack configs are written twice — once during the main pass, and again in `after_bundle`. Rails 8 runs its own `solid_*:install` generators after bundling, and those overwrite anything already there. The second write is what actually survives.

### Application code

| File | Purpose |
|---|---|
| `app/services/application_service.rb` | Service object base class with a `Result` struct |
| `app/lib/registry_base.rb` | Registry pattern module — `get`, `exists?`, `all_types`, `name`, `where`, `validate!`, `freeze!` |
| `app/lib/app_config.rb` | Working reference registry: branding, feature flags, limits, timing, an example `PlanRegistry` |
| `app/models/application_record.rb` | UUID primary keys, `implicit_order_column` |
| `app/helpers/structured_data_helper.rb` | `jsonld_tag` and `iso8601_duration` |
| `app/helpers/progress_bar_helper.rb` | Progress bar markup helper |
| `app/javascript/controllers/toggle_controller.js` | Generic show/hide Stimulus controller |
| `app/javascript/controllers/modal_controller.js` | Generic modal Stimulus controller |
| `app/controllers/home_controller.rb` | Landing page plus a dynamic `sitemap.xml` |
| `app/views/home/index.html.slim` | Placeholder home page |

### Deployment

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage production build |
| `bin/docker-entrypoint` | Runs migrations before boot |
| `.kamal/secrets` | Secret scaffold, gitignored |

### Testing and CI

| File | Purpose |
|---|---|
| `bin/test` | Test runner; forces a single worker on macOS where Minitest forking is flaky |
| `test/support/vcr.rb` | VCR configuration, required from `test_helper.rb` |
| `test/integration/seo_test.rb` | Asserts meta description, canonical URL, JSON-LD, sitemap, robots.txt |
| `.github/workflows/lighthouse.yml` | Weekly Lighthouse CI audit |
| `.github/lighthouse-budget.json` | Performance budget |

### SEO

| File | Purpose |
|---|---|
| `public/robots.txt` | Crawl rules and sitemap pointer |
| `HomeController#sitemap` | Dynamic XML sitemap at `/sitemap.xml` |
| Layout injections | `<meta name="description">`, `<link rel="canonical">`, `yield :head`, `WebSite` JSON-LD |

### Documentation

| File | Purpose |
|---|---|
| `CLAUDE.md` | Conventions, patterns, anti-patterns, Slim pitfalls — the file your AI agent reads |
| `docs/architecture.md` | Architecture Decision Records, pre-seeded with the template's own five decisions |
| `docs/design-patterns.md` | UI/UX patterns |
| `docs/models.md` | Model documentation stub |
| `docs/how-tos/add-seo-to-a-page.md` | Adding SEO to a new page |
| `docs/how-tos/harden-a-kamal-server.md` | Server hardening after `kamal setup` |
| `docs/how-tos/extract-database-and-storage.md` | Moving Postgres off the app server |

Empty `docs/plans/`, `docs/synthesis/`, and `docs/security/` directories are created as homes for feature plans, analysis, and audits.

---

## What the template changes about default Rails

Worth knowing, because these are the surprises:

1. **SQLite is removed.** PostgreSQL only.
2. **Four databases, not one.** Queue, cable, and cache each get their own, in every environment.
3. **UUID primary keys everywhere.** `rails g model` produces UUID PKs automatically. Foreign keys must be declared `t.uuid :parent_id`.
4. **Slim, not ERB.** The layout stays ERB (Devise and Rails generators expect it), but application views are Slim.
5. **Devise is installed but no `User` exists.** You run `rails g devise User` yourself.
6. **`app/lib` is autoloaded.** Registries live there.
7. **Development mail is captured**, not sent. `letter_opener_web` at `/letter_opener`.
8. **Development uses Solid Cable, not `:async`**, so WebSocket behaviour matches production.

---

## Removing things you don't want

Everything is a plain file. To drop a piece:

- **PaperTrail** — remove the gem, delete the versions migration, remove `has_paper_trail` calls
- **Petergate** — remove the gem and the `petergate` line from your User model
- **Slim** — remove `slim-rails`; existing `.slim` views need converting
- **SEO** — delete `structured_data_helper.rb`, `seo_test.rb`, the sitemap route and action, and the layout injections
- **VCR** — remove the gems and the `require_relative "support/vcr"` line in `test_helper.rb`

Nothing is coupled to anything else, with one exception: `app_config.rb` uses `RegistryBase`, so removing the registry module means removing or rewriting `AppConfig` too.
