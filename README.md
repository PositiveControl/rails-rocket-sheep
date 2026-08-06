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

- **Patterns exist before the agent arrives.** `ApplicationService` with a Result struct, `ApplicationForm` for multi-model forms, `ApplicationComponent` for UI units, `Data`-based registries for fixed variant sets, PaperTrail for audit trails, Discard for the tables that genuinely need soft deletes. The agent extends existing patterns instead of inventing new ones.
- **The conventions are written down.** A generated `CLAUDE.md` states the rules — Slim not ERB, service objects for business logic, scopes over class methods, UUIDs everywhere — with worked examples of both the right and wrong version.
- **Anti-patterns are named explicitly.** `CLAUDE.md` and the `docs/rules/` files name what not to do — N+1 iteration, premature `.to_a`, hardcoded entity knowledge, `accepts_nested_attributes_for`, model broadcasts for single-user updates — with the correct form beside each one. Agents follow negative examples well when you actually give them some.
- **The pattern budget is fixed.** Six sanctioned directories under `app/`: `services`, `forms`, `queries`, `policies`, `lib`, `components`. A seventh requires an ADR. Sprawl is the failure mode of a pattern catalogue, so the catalogue names its own limit.
- **Docs have a home.** `docs/system/architecture.md` for ADRs, `docs/sop/` for procedures, `docs/plans/` for feature plans. The agent has somewhere to put what it learns, so the next session starts informed.

The result is that the tenth feature looks like the first one.

---

## What you get

### Rails 8 Solid Stack, configured

Solid Queue, Solid Cache, and Solid Cable, each on its own database, with `queue.yml` / `cache.yml` / `cable.yml` and the multi-database `database.yml` already written. No Redis anywhere in the stack.

### Authentication and authorization

Devise, pre-configured for Turbo (`navigational_formats` set correctly — the fix everyone hits on day one). Petergate for role-based access.

### Data patterns

- **UUID primary keys** on every table, wired through the generators so `rails g model` does the right thing automatically
- **Discard** available for soft deletes, opt-in per table — `destroy` is the default, and PaperTrail can reify a destroyed record
- **PaperTrail** with `--with-changes` for a full audit trail
- **Pagy** for pagination, wired into `ApplicationController` and `ApplicationHelper` so `pagy(scope)` works out of the box

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

### Form objects

`ApplicationForm` — `ActiveModel::Model` plus attributes — for the submit that writes two models, or carries fields that aren't columns:

```ruby
class SignupForm < ApplicationForm
  attribute :email, :string
  attribute :company_name, :string
  validates :email, :company_name, presence: true

  def save
    return false if invalid?
    ApplicationRecord.transaction { ... }
    true
  end
end
```

The controller treats it exactly like a model. No `accepts_nested_attributes_for`, no error keys shaped like `items.attributes.0.quantity`.

### UI components

ViewComponent, configured for Slim sidecar directories, with `ApplicationComponent` and four working components — `AlertComponent`, `FlashComponent` (already wired into the layout), `ErrorSummaryComponent`, `EmptyStateComponent` — each with a unit test that runs without a request.

```bash
bin/rails generate component Badge label
# app/components/badge_component.rb
# app/components/badge_component/badge_component.html.slim
# test/components/badge_component_test.rb
```

### Registries for fixed variant sets

Plans, tiers, product types — anything with a fixed set of variants and per-variant attributes:

```ruby
module PlanRegistry
  Plan = Data.define(:key, :name, :price_cents, :features) do
    def free?                 = price_cents.zero?
    def has_feature?(feature) = features.include?(feature.to_sym)
  end

  ITEMS = {
    free: Plan.new(key: :free, name: "Free", price_cents: 0,     features: %i[basic_access]),
    pro:  Plan.new(key: :pro,  name: "Pro",  price_cents: 2_900, features: %i[basic_access api_access])
  }.freeze

  class << self
    def [](key) = ITEMS.fetch(key.to_sym)   # unknown key raises
    def all     = ITEMS.values
    def paid    = all.reject(&:free?)
  end
end

PlanRegistry[user.plan].has_feature?(:api_access)
```

No base class to learn. A mistyped attribute raises `NoMethodError` instead of returning `nil`; an unknown key raises `KeyError`; and `Data.define` requires every member, so an attribute can't be added to one variant and forgotten on the others. `app/lib/plan_registry.rb` ships as the canonical shape — copy it.

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

Minitest with a `bin/test` wrapper that works around the macOS forking issue, VCR + WebMock for HTTP recording, Slowpoke for slow-test reporting, Bullet for N+1 detection in development, RuboCop (Rails Omakase), Brakeman, and `letter_opener_web` for previewing mail at `/letter_opener`.

Slowpoke prints any test over 500ms after the run and nothing at all when the suite is clean. `SLOWPOKE_THRESHOLD`, `SLOWPOKE_MAX_RESULTS`, `SLOWPOKE_HISTORY`, and `SLOWPOKE_CI` tune it per run; `SLOWPOKE_CI=true` fails the build on a slow test once the suite is under the line.

### Frontend

Tailwind CSS, Slim templates, ViewComponent, and generic `toggle_controller.js` / `modal_controller.js` Stimulus controllers that cover most of what you'd otherwise write twice. The Turbo status contract, strict locals for partials, and the Stimulus target/value/class rules each get their own rule file in `docs/rules/` — the failures they prevent are silent ones.

---

## Documentation

| Guide | What's in it |
|---|---|
| [Getting Started](docs/getting-started.md) | Prerequisites, first run, what to do in the first ten minutes |
| [What's Included](docs/whats-included.md) | Every gem and file the template adds, and why |
| [Working With AI Agents](docs/working-with-ai-agents.md) | How the conventions are structured, and how to extend them |
| [The Agent Workflow](docs/workflow.md) | The 19 slash commands, the four gates, sizing rules, setup |
| [Agent Guardrails](docs/agent-guardrails.md) | Permissions and hooks — enforcement, not just conventions |
| [Inventory & Gaps](docs/inventory.md) | What's included, what isn't, and what's next |
| [Deployment](docs/deployment.md) | Kamal from zero to a deployed app on a fresh VPS |
| [Comparison](docs/comparison.md) | Honest comparison against plain `rails new`, Jumpstart Pro, and Bullet Train |
| [FAQ](docs/faq.md) | Ruby/Rails versions, removing pieces, upgrades, licensing |

The patterns themselves — service objects, registries, form objects, components, soft deletes, audit trails, with worked examples of the right and wrong version — are documented inside every generated app as `docs/rules/`, one convention per file.

Each generated app also ships: `docs/rules/` (36 rules + a routing index), `docs/system/architecture.md`, `docs/system/models.md`, and how-to guides for SEO, Kamal hardening, and extracting the database to a separate host.

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
- **Not a component library.** ViewComponent is set up and four utility components ship (alert, flash, error summary, empty state). Buttons, tables, navs, and everything else are yours to write.
- **Not a framework.** Everything it adds is a plain Rails file you own and can delete. There is no gem to depend on, no upgrade treadmill, and nothing that breaks when Rails 8.1 ships.

---

## License

Commercial license — see [LICENSE](LICENSE) for the full terms.

Two tiers: **Single Application** and **Unlimited Applications**. Both are perpetual one-time purchases, not subscriptions.

Apps you generate are entirely yours — no royalties, no attribution, and you may open-source them. The template is applied once and leaves behind ordinary Rails files with no runtime dependency on it. What the license restricts is redistributing the *template*, not anything you build with it.
