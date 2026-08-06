# Rails Rocket Sheep 🚀🐑

**A Rails 8 template built for working with AI coding agents.**

`rails new` gives you a framework. Rocket Sheep gives you a codebase an agent can be productive in on the first prompt — because the patterns are already there, already documented, and already written down in a `CLAUDE.md` the agent reads before it touches anything.

```bash
rails new myapp \
  --database=postgresql \
  --template=https://raw.githubusercontent.com/PositiveControl/rails-rocket-sheep/main/template.rb
```

Roughly three minutes later you have a running, deployable, linted, tested Rails 8 app with authentication, background jobs, SEO, and a Kamal deploy config — plus the conventions doc that keeps an agent from inventing its own.

---

## The problem this solves

Point an AI agent at a fresh `rails new` app and it will make reasonable choices. The trouble is it makes *different* reasonable choices every session. One feature gets a service object, the next gets a fat controller. One model uses soft deletes, the next uses `destroy`. Business logic lands wherever the context window happened to be pointing.

You end up as a full-time code reviewer for an codebase with no opinions.

Rocket Sheep front-loads the opinions:

- **Patterns exist before the agent arrives.** `ApplicationService` with a Result struct, `RegistryBase` for configuration entities, Discard for soft deletes, PaperTrail for audit trails. The agent extends existing patterns instead of inventing new ones.
- **The conventions are written down.** A generated `CLAUDE.md` states the rules — Slim not ERB, service objects for business logic, scopes over class methods, UUIDs everywhere — with worked examples of both the right and wrong version.
- **Anti-patterns are named explicitly.** The `CLAUDE.md` contains a list of things not to do (N+1 iteration, premature `.to_a`, hardcoded entity knowledge) with the correct form beside each one. Agents follow negative examples well when you actually give them some.
- **Docs have a home.** `docs/architecture.md` for ADRs, `docs/how-tos/` for procedures, `docs/plans/` for feature plans. The agent has somewhere to put what it learns, so the next session starts informed.

The result is that the tenth feature looks like the first one.

---

## What you get

### Rails 8 Solid Stack, configured

Solid Queue, Solid Cache, and Solid Cable, each on its own database, with `queue.yml` / `cache.yml` / `cable.yml` and the multi-database `database.yml` already written. No Redis anywhere in the stack.

### Authentication and authorization

Devise, pre-configured for Turbo (`navigational_formats` set correctly — the fix everyone hits on day one). Petergate for role-based access.

### Data patterns

- **UUID primary keys** on every table, wired through the generators so `rails g model` does the right thing automatically
- **Discard** for soft deletes
- **PaperTrail** with `--with-changes` for a full audit trail
- **Pagy** for pagination

### Service objects with a Result type

```ruby
class CreateOrderService < ApplicationService
  def initialize(user:, items:)
    @user, @items = user, items
  end

  def call
    order = Order.new(user: @user, items: @items)
    order.save ? success(order) : failure(order.errors.full_messages)
  end
end

result = CreateOrderService.call(user: current_user, items: cart_items)
result.success? ? redirect_to(result.value) : render(:new)
```

`Result` is a `Struct` with `success?`, `failure?`, `value`, `errors`, and a `record` alias. Services get `log_error` and `log_info` helpers that tag output with the class name.

### Registry pattern for configuration entities

Plans, tiers, product types, anything with a fixed set of variants and per-variant attributes:

```ruby
module PlanRegistry
  extend RegistryBase

  ITEMS = {
    free: { name: "Free", price_cents: 0,    features: %i[basic_access] },
    pro:  { name: "Pro",  price_cents: 2900, features: %i[basic_access api_access webhooks] }
  }.freeze

  class << self
    def items = ITEMS
    def price_cents(type) = get(type, :price_cents)
    def has_feature?(type, feature) = (get(type, :features) || []).include?(feature.to_sym)
    def paid_plans = items.reject { |_, v| v[:price_cents].zero? }.keys
  end
end
```

`RegistryBase` supplies `get`, `exists?`, `all_types`, `name`, `where`, `validate!`, and `freeze!`. A working `AppConfig` registry ships as a reference implementation.

### SEO foundation

Not a checkbox — an actual working setup:

- `public/robots.txt` with sane crawl rules
- Dynamic `/sitemap.xml` from `HomeController#sitemap`
- `<meta name="description">` and `<link rel="canonical">` in the layout, with per-page `content_for` overrides
- `StructuredDataHelper#jsonld_tag` plus a `WebSite` JSON-LD block on every page
- **Integration tests** in `test/integration/seo_test.rb` that assert the tags are actually there
- Lighthouse CI workflow with a performance budget

### Deployment

Kamal 2 with a PostgreSQL accessory, a tuned multi-stage `Dockerfile`, a `docker-entrypoint` that runs migrations, and a `.kamal/secrets` scaffold. `kamal setup && kamal deploy` from a clean server.

### Testing and code quality

Minitest with a `bin/test` wrapper that works around the macOS forking issue, VCR + WebMock for HTTP recording, Bullet for N+1 detection in development, RuboCop (Rails Omakase), Brakeman, and `letter_opener_web` for previewing mail at `/letter_opener`.

### Frontend

Tailwind CSS, Slim templates, and generic `toggle_controller.js` / `modal_controller.js` Stimulus controllers that cover most of what you'd otherwise write twice.

---

## Documentation

| Guide | What's in it |
|---|---|
| [Getting Started](docs/getting-started.md) | Prerequisites, first run, what to do in the first ten minutes |
| [What's Included](docs/whats-included.md) | Every gem and file the template adds, and why |
| [Working With AI Agents](docs/working-with-ai-agents.md) | How the conventions are structured, and how to extend them |
| [Patterns](docs/patterns.md) | Service objects, registries, soft deletes, audit trails — with worked examples |
| [Deployment](docs/deployment.md) | Kamal from zero to a deployed app on a fresh VPS |
| [Comparison](docs/comparison.md) | Honest comparison against plain `rails new`, Jumpstart Pro, and Bullet Train |
| [FAQ](docs/faq.md) | Ruby/Rails versions, removing pieces, upgrades, licensing |

Each generated app also ships its own docs: `docs/architecture.md`, `docs/design-patterns.md`, `docs/models.md`, and how-to guides for SEO, Kamal hardening, and extracting the database to a separate host.

---

## Requirements

- Ruby 3.2+ (developed and tested on 3.4)
- Rails 8.0+
- PostgreSQL 13+ (uses built-in `gen_random_uuid()`, no pgcrypto extension needed)
- Node.js — only if you swap Tailwind for a bundler-based frontend

---

## After generation

```bash
cd myapp
rails g devise User    # create your User model
bin/dev                # http://localhost:3000
bin/test               # run the suite
```

Then edit `config/deploy.yml`, fill in `.kamal/secrets`, and update the sitemap URL in `public/robots.txt`.

See [Getting Started](docs/getting-started.md) for the full walkthrough.

---

## What this is not

Honest scope, so nobody buys the wrong thing:

- **Not a SaaS starter kit.** No billing, no subscriptions, no teams, no admin panel. If you want Stripe and multi-tenancy pre-built, Jumpstart Pro is the better purchase. Rocket Sheep is a *foundation*, not an application.
- **Not a component library.** Tailwind is configured; the components are yours to write.
- **Not a framework.** Everything it adds is a plain Rails file you own and can delete. There is no gem to depend on, no upgrade treadmill, and nothing that breaks when Rails 8.1 ships.

---

## License

Commercial license. Full terms accompany purchase.

Apps you generate are yours — the template is applied once and leaves behind ordinary Rails files with no runtime dependency on it.
