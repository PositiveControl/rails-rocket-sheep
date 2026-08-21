# Getting Started

From nothing to a running app in about three minutes, plus what to do in the ten minutes after that.

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Ruby | 3.2+ | Developed and tested on 3.4.7 |
| Rails | 8.0+ | `gem install rails` |
| PostgreSQL | 13+ | Must be running before you generate. Uses built-in `gen_random_uuid()`. |
| Git | any | The template commits for you at the end |

Check that Postgres is actually up before you start — the template runs `db:create` and `db:migrate` at the end, and a dead server means a half-generated app:

```bash
pg_isready
```

---

## Generate

```bash
rails new myapp \
  --database=postgresql \
  --template=https://raw.githubusercontent.com/PositiveControl/rails-rocket-sheep/main/template.rb
```

The URL form shallow-clones this repo to a temp directory first — `--template` only
fetches `template.rb` itself, not the `templates/` tree it copies from — so `git`
must be on your PATH.

Or from a local clone, which is faster if you're generating more than one app:

```bash
git clone https://github.com/PositiveControl/rails-rocket-sheep.git
rails new myapp --database=postgresql --template=rails-rocket-sheep/template.rb
```

The template runs in fourteen phases and narrates each one. It finishes by bundling, installing Devise and PaperTrail, installing Tailwind, creating and migrating the database, and making an initial git commit.

---

## First ten minutes

### 1. Create your User model

The template installs and configures Devise but deliberately does not generate a `User` — your app's user model is yours to shape.

```bash
cd myapp
rails g devise User
rails db:migrate
```

The generated migration uses a UUID primary key automatically, because the template configured the generators to.

### 2. Start the server

```bash
bin/dev
```

This runs Rails and the Tailwind watcher together. Visit http://localhost:3000 for the placeholder home page, which shows sign-in and sign-up links once `User` exists.

### 3. Run the tests

```bash
bin/test                              # everything
bin/test test/models/                 # a directory
bin/test test/models/user_test.rb:42  # one test
```

`bin/test` exists because Minitest's parallel forking is unreliable on macOS. It forces a single worker there and behaves normally on Linux/CI.

The SEO integration tests in `test/integration/seo_test.rb` pass out of the box. If they start failing, you broke the layout.

### 4. Check your mail

Development mail goes to `letter_opener_web`, not to a real inbox. Anything your app sends shows up at http://localhost:3000/letter_opener.

---

## Configure before deploying

Four files have placeholder values that must be changed. None of them will break locally, so it's easy to forget until you're live:

| File | What to change |
|---|---|
| `config/deploy.yml` | Server IP/hostname, Docker registry, domain for the proxy |
| `.kamal/secrets` | Registry password, `POSTGRES_PASSWORD`, database URLs |
| `public/robots.txt` | The `Sitemap:` URL — currently points at `example.com` |
| `.github/workflows/lighthouse.yml` | The production URL to audit |

`app/lib/app_config.rb` also carries placeholder branding (`name`, `tagline`, `support_email`). Update it or delete it. Alongside it, `app/lib/plan_registry.rb` is the canonical registry shape — a worked example to copy, not something the app depends on.

See [Deployment](deployment.md) for the full Kamal walkthrough.

---

## Project layout

```
app/
├── lib/                     # Registries and config modules (autoloaded)
├── models/                  # ActiveRecord models — UUID PKs by default
├── services/                # Service objects, inherit ApplicationService
├── forms/                   # Form objects, inherit ApplicationForm
├── components/              # ViewComponents, inherit ApplicationComponent
├── controllers/
├── jobs/                    # Background jobs (Solid Queue)
├── helpers/
├── views/                   # Slim templates
└── javascript/controllers/  # Stimulus

# Created on first use, not shipped empty:
#   app/queries/             # Query objects — reads joining 2+ models
#   app/policies/            # Record-level authorization

docs/                        # Names are load-bearing
├── rules/                   # One convention per file + INDEX.md router
├── plans/                   # Feature design docs
├── system/
│   ├── architecture.md      # ADRs — record decisions here
│   └── models.md            # Model documentation
├── sop/                     # Procedures / how-tos
└── qa/                      # Manual test guides

.kamal/secrets               # Gitignored
CLAUDE.md                    # Conventions your AI agent reads
```

`app/lib` is added to the autoload paths by the template, so registries are available without requires.

---

## Common first problems

**`PG::ConnectionBad` during generation.** Postgres wasn't running. Start it, delete the half-generated directory, and run the generator again.

**Devise routes missing from the home page.** You haven't run `rails g devise User` yet. The home view calls `user_signed_in?`, which needs the Devise model to exist.

**Tailwind classes with brackets don't render.** Slim parses `[` specially. Use the explicit attribute form — `div class="max-h-[85vh]"` rather than `.max-h-[85vh]`. This and other Slim gotchas are in `docs/rules/slim-gotchas.md`.

**A form submits and nothing happens.** The controller rendered a validation failure with a 200. Turbo discards it silently. Render with `status: :unprocessable_content` — see `docs/rules/turbo-status.md`.

**`bin/dev` says the port is in use.** Another Rails app is running. `lsof -ti:3000 | xargs kill` or run with `-p 3001`.

---

## Next

- [What's Included](whats-included.md) — every gem and file, and why it's there
- `docs/rules/INDEX.md` in your new app — service objects, form objects, registries, components, and the rest, one rule per file
- [Working With AI Agents](working-with-ai-agents.md) — the part that makes this template different
- [Staying Current](staying-current.md) — taking template fixes later, and adopting the workflow into an app that wasn't generated from it
