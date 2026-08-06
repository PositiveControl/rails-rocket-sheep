# Design Patterns

Backend patterns for a server-rendered Rails monolith: controllers, business logic,
models, jobs, caching, authorization.

View-layer patterns — Slim, Tailwind, ViewComponent, Turbo, Stimulus — live in
[`ui-patterns.md`](ui-patterns.md).

---

## How to choose

A pattern earns a place in this app only if it clears three bars:

1. **It recurs.** Not once — most weeks.
2. **The wrong default is expensive.** Silent Turbo failures, N+1s, unbounded queries.
3. **A reviewer can check it in a diff.** If nobody can tell whether the rule was
   followed, it isn't a rule, it's a mood.

Everything below clears all three. Patterns that don't are listed under
[Rejected patterns](#rejected-patterns), with the reason.

### Pattern budget

The failure mode of a pattern catalogue is sprawl: eight directories under `app/`
each holding two files nobody can tell apart.

| Directory | Holds | Add a file when |
|---|---|---|
| `app/services/` | Multi-step writes with a failure path | An operation touches >1 model or is called from >1 place |
| `app/forms/` | Form objects for multi-model or non-AR forms | One form writes to two models, or to none |
| `app/queries/` | Reads that join ≥2 models | A scope would need a join and 3+ clauses |
| `app/policies/` | Record-level authorization | The answer depends on the record, not just the role |
| `app/lib/` | Registries — fixed variant sets | Values are code, not user data |
| `app/components/` | Rendered UI units | See `ui-patterns.md` |

Six. Not seven. A new top-level directory under `app/` is an architecture decision:
record it as an ADR in [`architecture.md`](architecture.md) or don't create it.

The default for any given piece of code is still **a model method, a scope, or a
controller action**. Reach for a pattern when plain Rails has actually run out.

---

## Controllers

### Stay RESTful — a new verb is a new resource

Custom actions are how a controller becomes an unreadable 400-line switchboard.
When you want a verb, model it as a resource with CRUD instead.

```ruby
# BAD — verbs pile up on one controller
resources :orders do
  member do
    patch :archive
    patch :unarchive
    post  :duplicate
    post  :send_receipt
  end
end

# GOOD — each verb is a resource with a standard action
resources :orders do
  resource  :archive,  only: [:create, :destroy]   # Orders::ArchivesController
  resources :duplicates, only: [:create]           # Orders::DuplicatesController
  resources :receipts,   only: [:create]           # Orders::ReceiptsController
end
```

```ruby
# app/controllers/orders/archives_controller.rb
module Orders
  class ArchivesController < ApplicationController
    def create
      order = current_user.orders.find(params[:order_id])
      result = ArchiveOrderService.call(order:)

      if result.success?
        redirect_to order, notice: "Order archived"
      else
        redirect_to order, alert: result.errors.join(", ")
      end
    end
  end
end
```

**The rule:** seven actions per controller — `index show new create edit update destroy`.
Anything else gets its own controller. Nested controllers go under a module named
after the parent resource.

**Why it pays:** every controller has the same shape, so routes are guessable,
authorization hooks land in predictable places, and the class stays small enough to
read in one screen.

**When not to:** genuinely stateless endpoints with no resource behind them —
a webhook receiver, a health check. Those get their own controller anyway.

### Controller actions stay under ten lines

An action does four things and nothing else:

```ruby
def create
  result = CreateOrderService.call(user: current_user, items: order_params[:items])

  if result.success?
    redirect_to result.value, notice: "Order placed"
  else
    @order = result.value
    render :new, status: :unprocessable_content
  end
end
```

Find, delegate, branch, respond. Business logic that appears in a controller is
logic that a job, a console session, and a test can't reach.

### The Turbo status contract

**This is the one that silently eats bug reports.** Turbo Drive discards a form
response with a 2xx status and no redirect — the page does not change, no error
appears, and the user re-submits forever.

| Outcome | Response |
|---|---|
| Success | `redirect_to`, any 3xx |
| Validation failure | `render :new, status: :unprocessable_content` |
| Not authorized | `redirect_to root_path, alert: …` or `head :forbidden` |
| Not found | `raise ActiveRecord::RecordNotFound` — let the boundary handle it |

```ruby
# BAD — Turbo ignores this. The form appears frozen.
render :new

# GOOD
render :new, status: :unprocessable_content
```

**On the status name:** Rack 3.1 renamed 422 from `:unprocessable_entity` to
`:unprocessable_content`, matching the IANA registry; Rack 3.2 warns on the old
name. Rails 8 accepts both and maps between them. Use `:unprocessable_content`
in new code. Expect `:unprocessable_entity` in older gems' docs — it still works.

Every controller test that renders a form failure should assert the status:

```ruby
test "rejects invalid order" do
  post orders_path, params: { order: { total_cents: -1 } }
  assert_response :unprocessable_content
end
```

### Every index paginates

Pagy is installed. An index action with no limit is a production incident with a
delay fuse — it works for months, then a customer has 40,000 rows.

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pagy::Backend
end

# app/helpers/application_helper.rb
module ApplicationHelper
  include Pagy::Frontend
end

# app/controllers/orders_controller.rb
def index
  @pagy, @orders = pagy(current_user.orders.kept.includes(:items).recent, limit: 25)
end
```

```slim
/ app/views/orders/index.html.slim
= render OrdersTableComponent.new(orders: @orders)
== pagy_nav(@pagy)
```

**The rule:** if a collection can grow with usage, it paginates. No exceptions for
admin screens — admin screens are where the 40,000 rows live.

### Rate-limit what strangers can reach

Rails 8 ships rate limiting. It uses `Rails.cache`, which here is Solid Cache, so
there is nothing to install.

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes,
             only: :create,
             with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again shortly." }
end

class PasswordResetsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create,
             by:   -> { params.dig(:user, :email).to_s.downcase },
             with: -> { head :too_many_requests }
end
```

Defaults: `by:` is the remote IP, `with:` is `head :too_many_requests`.

**Apply to:** sign-in, password reset, signup, invite acceptance, contact forms,
webhook endpoints, anything that sends mail or costs money per call.

**Don't apply to:** authenticated CRUD. You'll rate-limit your own power users.

### One exception boundary, not fifty rescues

```ruby
class ApplicationController < ActionController::Base
  class Forbidden < StandardError; end

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Forbidden,                    with: :access_denied

  private

  def not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found }
      format.any  { head :not_found }
    end
  end

  def access_denied
    redirect_back fallback_location: root_path, alert: "You don't have access to that."
  end
end
```

**The rule:** scope every lookup to what the user may see and let the miss raise.

```ruby
# BAD — leaks existence, and 500s in production
@order = Order.find(params[:id])
redirect_to root_path if @order.user != current_user

# GOOD — a foreign id is indistinguishable from a deleted one: 404
@order = current_user.orders.find(params[:id])
```

Never `rescue Exception`, never `rescue => e` around a whole action. A rescue that
can't say what it's recovering from is hiding the bug, not handling it.

---

## Business logic

### Service objects

Full reference: the class comment in `app/services/application_service.rb`.

```ruby
class CreateOrderService < ApplicationService
  def initialize(user:, items:)
    @user  = user
    @items = items
  end

  def call
    return failure("Items can't be empty") if @items.empty?

    order = Order.new(user: @user, items: @items)

    if order.save
      log_info("Order created", order_id: order.id)
      success(order)
    else
      failure(order.errors.full_messages)
    end
  end
end
```

| Use a service when | Don't when |
|---|---|
| The operation touches >1 model | It's single-model validation → model concern |
| It has a failure mode the caller must handle | It's one query → scope |
| It's called from >1 place (controller + job) | It's formatting → helper or component |
| The action would push a controller past ~10 lines | It wraps a single `create!` → just call `create!` |

Return `failure()` for expected outcomes — validation, business rules, a declined
card. `raise` for broken invariants, and define the error class on the service.

**Transactions belong in the service**, not the controller and not a callback:

```ruby
def call
  ApplicationRecord.transaction do
    order.update!(status: :paid)
    Ledger.record!(order)
    order
  end
  success(order)
rescue ActiveRecord::RecordInvalid => e
  failure(e.record.errors.full_messages)
end
```

### Form objects

The biggest gap in a plain Rails app: a form that writes two models, or none.
`accepts_nested_attributes_for` is the alternative and it is worse — it hides
writes inside a model's assignment path and makes error messages unspeakable.

```ruby
# app/forms/application_form.rb
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
end
```

```ruby
# app/forms/signup_form.rb
class SignupForm < ApplicationForm
  attribute :email,        :string
  attribute :password,     :string
  attribute :company_name, :string
  attribute :accept_terms, :boolean, default: false

  validates :email, :password, :company_name, presence: true
  validates :accept_terms, acceptance: true

  attr_reader :user

  def save
    return false if invalid?

    ApplicationRecord.transaction do
      company = Company.create!(name: company_name)
      @user   = company.users.create!(email:, password:, role: :owner)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.merge!(e.record)
    false
  end
end
```

The controller treats it exactly like a model — that's the whole point:

```ruby
def new
  @form = SignupForm.new
end

def create
  @form = SignupForm.new(signup_params)

  if @form.save
    sign_in @form.user
    redirect_to dashboard_path, notice: "Welcome"
  else
    render :new, status: :unprocessable_content
  end
end
```

```slim
= form_with model: @form, url: signup_path do |f|
  = render ErrorSummaryComponent.new(record: @form)
  = f.email_field :email
  = f.password_field :password
  = f.text_field :company_name
```

**Reach for a form object when:** one submit writes to ≥2 models; the form has
fields that aren't columns (`accept_terms`, `confirm_email`); a wizard step needs
partial validation; or the same model needs different validation rules in two
contexts (admin edit vs. self-serve edit).

**Don't when:** the form maps to one model. `form_with model: @order` is already
the right answer, and a form object around it is pure ceremony.

**Form object vs. service:** the form owns validation and the shape of user input;
a service owns coordination. A form object may call a service. A service should
never know a form exists.

### Query objects

Scopes are the default. A query object starts where scopes stop being readable.

```ruby
# app/queries/stale_orders_query.rb
class StaleOrdersQuery
  def initialize(relation = Order.kept)
    @relation = relation
  end

  def call(older_than: 30.days.ago, minimum_cents: 0)
    @relation
      .joins(:customer)
      .left_joins(:shipments)
      .where(shipments: { id: nil })
      .where(orders: { created_at: ...older_than })
      .where(orders: { total_cents: minimum_cents.. })
      .group("orders.id")
      .order("orders.created_at ASC")
  end
end

# Usage — still a relation, so it chains and paginates
@pagy, @orders = pagy(StaleOrdersQuery.new.call(older_than: 60.days.ago))
```

| Where it goes | Rule |
|---|---|
| Scope | Single model, one or two clauses |
| Scope composition | Single model, several named scopes chained at the call site |
| Query object | Joins ≥2 models, or >3 clauses, or takes arguments that change its shape |

**Always return a relation, never an array.** Returning `.to_a` kills chaining,
kills pagination, and forces the whole result set into memory.

**Never `to_a` early to filter in Ruby:**

```ruby
# BAD — loads every active user to find the admins
User.where(active: true).to_a.select(&:admin?)

# GOOD
User.where(active: true).where(role: :admin)
```

### Policy objects

Petergate handles **role**-level access — "can admins reach this controller?" —
and that's where role rules stay:

```ruby
class OrdersController < ApplicationController
  access all: [:show, :index], user: { except: [:destroy] }, admin: :all
end
```

Petergate also gives you `forbidden!` for a hand-rolled guard in a `before_action`.

Petergate does not answer **record**-level questions — "can *this* user edit
*this* order?" Those go in a policy object, so the same rule is reachable from a
controller, a view, and a job.

```ruby
# app/policies/order_policy.rb
class OrderPolicy
  def initialize(user, order)
    @user  = user
    @order = order
  end

  def edit?    = owner? && @order.draft?
  def cancel?  = owner? && !@order.shipped?
  def refund?  = @user.admin? && @order.paid?

  private

  def owner? = @order.user_id == @user.id
end
```

```ruby
# controller — the boundary turns this into a redirect with a flash
raise Forbidden unless OrderPolicy.new(current_user, @order).cancel?
```

```slim
/ view — same rule, one source
- if OrderPolicy.new(current_user, @order).cancel?
  = button_to "Cancel", order_cancellation_path(@order), method: :post
```

**The anti-pattern it replaces:** `if current_user.admin? || order.user == current_user`
copy-pasted into a controller and two views, where one copy is eventually wrong
and it's the one in the view that hides the button but not the route.

**Every policy question gets a test.** They're pure functions of two objects —
the cheapest tests in the suite and the ones that matter most.

### Registries

For fixed variant sets carrying attributes — plans, tiers, roles, product types.
Values that are code, change with deploys, and need to be greppable.

`app/lib/plan_registry.rb` ships as the canonical shape. Copy it.

```ruby
module PlanRegistry
  # Nested under the module — Zeitwerk expects plan_registry.rb to define
  # PlanRegistry and anything inside it. A top-level `Plan` breaks eager load.
  Plan = Data.define(:key, :name, :price_cents, :features, :limits) do
    def free?                 = price_cents.zero?
    def has_feature?(feature) = features.include?(feature.to_sym)
    def limit(name)           = limits[name.to_sym]
  end

  ITEMS = {
    free: Plan.new(key: :free, name: "Free", price_cents: 0,
                   features: %i[basic_access], limits: { projects: 3 }),
    pro:  Plan.new(key: :pro, name: "Pro", price_cents: 2_900,
                   features: %i[basic_access api_access], limits: { projects: 100 })
  }.freeze

  class << self
    def [](key)   = ITEMS.fetch(key.to_sym)   # unknown key raises KeyError
    def find(key) = ITEMS[key.to_sym]         # when a miss is legitimate
    def all       = ITEMS.values
    def paid      = all.reject(&:free?)
  end
end
```

```ruby
PlanRegistry[:pro].price_cents                  # => 2900
PlanRegistry[user.plan].has_feature?(:api_access)
PlanRegistry.paid.map(&:name)                   # => ["Pro"]
```

**Three rules:**

1. **Entries are `Data` objects, not hashes.** A typo raises `NoMethodError` at
   the call site instead of returning `nil` three layers away in a view, and
   behaviour lives with the data instead of being reimplemented by each caller.
   `Data.define` requires every member at construction, so an attribute added to
   one variant can't be forgotten on the others.
2. **Lookup is `fetch`.** An unknown key raises. `find` exists for the cases where
   a miss is legitimate — say a key arriving from params.
3. **Query capabilities, not identities.** `has_feature?(:api_access)` keeps
   working when a plan is added; `plan == "pro" || plan == "enterprise"` silently
   excludes it. This is the half that actually matters.

**Move it to a table when** non-developers must edit it, or values must change
without a deploy. Not before — a table turns every feature check into a query and
every typo into a runtime `nil`.

**Not a registry:** constants with no variants. Branding strings, upload limits,
timeouts. Those are frozen constants — see `app/lib/app_config.rb`.

---

## Models

### Scopes, not class methods

```ruby
# BAD
def self.recent = where("created_at > ?", 1.week.ago)

# GOOD
scope :recent,     -> { where(created_at: 1.week.ago..) }
scope :unshipped,  -> { where(shipped_at: nil) }
scope :for_user,   ->(user) { where(user:) }
```

Scopes always return a relation, even when they match nothing — a class method
can accidentally return `nil` and break the chain three calls later.

### Callbacks: same record only

The single largest source of "why did this row change" bugs.

```ruby
# BAD — a save on Order silently writes two other tables and sends mail
class Order < ApplicationRecord
  after_create :charge_customer, :notify_warehouse, :update_inventory
end

# GOOD — the callback touches only its own record
class Order < ApplicationRecord
  before_validation :normalize_email
  before_save       :calculate_total_cents
end
```

| Allowed in a callback | Belongs in a service |
|---|---|
| Normalizing this record's attributes | Writing other models |
| Deriving a column from other columns on this record | Sending mail or notifications |
| Setting a default that validation needs | Calling an external API |
| | Enqueuing jobs (except trivially, via `after_commit`) |

If a job must be enqueued from a model, use `after_commit` — never `after_save`,
which fires inside the transaction and can enqueue work for a row that then
rolls back, giving the worker a record that does not exist.

### N+1 queries

Bullet is installed in development and will tell you. Don't wait for it.

```ruby
# BAD — one query per row
@orders = Order.recent
@orders.each { |o| o.customer.name }

# GOOD
@orders = Order.recent.includes(:customer)
```

```ruby
# BAD — a COUNT per row
users.each { |u| u.orders.count }

# GOOD — counter cache column, no query at all
class Order < ApplicationRecord
  belongs_to :user, counter_cache: true
end
users.each { |u| u.orders_count }
```

`includes` when you read the association. `counter_cache` when you only need the
number. `size` over `count` on a loaded association — `count` always hits the
database, `size` uses what's already there.

**Sort and aggregate in the database, not in Ruby:**

```ruby
# BAD
users.to_a.sort_by { |u| u.orders.count }

# GOOD
User.left_joins(:orders).group(:id).order("COUNT(orders.id) DESC")
```

### Deletes: real by default

`destroy` is the default. Soft deletes are a per-table decision, not a house style.

Discard is installed for when you need it:

```ruby
class Post < ApplicationRecord
  include Discard::Model
end

post.discard    # sets discarded_at
Post.kept       # not discarded
```

**Add it to a model when** restoration is a product feature the user can reach, or
an audit obligation requires the row to survive, or foreign keys point at the row
from records that must stay valid. Those are real reasons and they apply to a
handful of tables, not all of them.

**The trap:** Discard adds no default scope, deliberately — default scopes are
notoriously hard to escape. `Post.all` still returns discarded rows. Every query,
every association, and every authorization check on a discardable model is a place
to forget `.kept`, and the failure is silent. That cost is permanent and it lands
on every future query against that table.

**Before reaching for it,** check whether PaperTrail already answers the question.
It's installed, and it can restore a destroyed record:

```ruby
version = PaperTrail::Version.where(item_type: "Post", item_id: id, event: "destroy").last
post = version.reify
post.save!
```

That covers "an admin deleted the wrong thing" without taxing every query. It does
*not* restore associations or keep foreign keys valid in the meantime — when those
matter, use Discard.

### Audit trail

```ruby
class Order < ApplicationRecord
  has_paper_trail only: [:status, :total_cents]
end
```

**The cost:** a `versions` row per create, update, and destroy. Track models where
history has value — orders, permissions, financial records — and scope with `only:`
on noisy ones. Not every model you own.

---

## Jobs

### A job is a thin wrapper over a service

```ruby
# BAD — logic lives in the job, unreachable from the console or a controller
class ChargeOrderJob < ApplicationJob
  def perform(order)
    # 40 lines of payment logic
  end
end

# GOOD
class ChargeOrderJob < ApplicationJob
  queue_as :default
  retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order            # deleted between enqueue and run
    return if order.paid?          # idempotent: already done

    result = ChargeOrderService.call(order:)
    raise result.errors.join(", ") unless result.success?
  end
end
```

**Pass IDs, not records.** GlobalID serialization of a deleted record raises
`DeserializationError` on every retry. An ID lets the job decide what a missing
row means.

**Assume it runs twice.** Solid Queue retries, and a retry after a partial success
is the normal case, not the edge case. Every `perform` starts with a guard that
makes a second run a no-op.

**Enqueue after commit,** never mid-transaction:

```ruby
# BAD — worker may pick this up before the row is committed
order.save!
ChargeOrderJob.perform_later(order.id)   # inside a surrounding transaction

# GOOD
ApplicationRecord.transaction do
  order.save!
end
ChargeOrderJob.perform_later(order.id)
```

**Queue names are a capacity decision.** `:default` for user-facing work,
`:low` for backfills and reports. Configure the split in `config/queue.yml`
before you need it, not during the incident.

---

## Caching

Solid Cache is configured and database-backed. That makes reads cheap and makes
cache writes real writes — cache deliberately, not everywhere.

### Russian-doll fragment caching

```slim
/ app/views/orders/index.html.slim
- cache [current_user, @orders.maximum(:updated_at), @orders.size] do
  - @orders.each do |order|
    - cache order do
      = render OrderRowComponent.new(order:)
```

Touch the parent so an inner change busts the outer key:

```ruby
class OrderItem < ApplicationRecord
  belongs_to :order, touch: true
end
```

`cache order` keys on class, id, and `updated_at` — no manual expiry, no stale
fragments, no `Rails.cache.delete` calls to keep in sync.

### What to cache

| Cache | Don't cache |
|---|---|
| Rendered fragments of expensive collections | Anything containing another user's data |
| Aggregates that tolerate seconds of staleness | Authorization results |
| External API responses (`fetch` with `expires_in`) | Anything already fast |

```ruby
Rails.cache.fetch(["exchange_rate", currency], expires_in: 1.hour) do
  ExchangeRateApi.fetch(currency)
end
```

**Always include the user in the key** for anything user-scoped. A cache key
missing a tenant discriminator is a data leak, and it will not show up in tests.

**Measure before caching.** A cached slow query is still a slow query on every
cold key, plus a new class of staleness bug. Fix the query first.

---

## Optional patterns

Reach for these when the situation actually arises. They don't ship as base classes.

### Value objects

For a pair of columns that always travel together and carry behavior:

```ruby
class Money
  include Comparable
  attr_reader :cents, :currency

  def initialize(cents, currency = "USD")
    @cents, @currency = cents, currency
  end

  def +(other)  = Money.new(cents + other.cents, currency)
  def to_s      = format("$%.2f", cents / 100.0)
  def <=>(other) = cents <=> other.cents
end

class Order < ApplicationRecord
  def total = Money.new(total_cents, currency)
end
```

Frozen, comparable, no persistence. Stop money formatting from spreading into
fifteen views.

### Status columns

Use a Rails enum for the states, a registry when each state carries attributes:

```ruby
class Order < ApplicationRecord
  enum :status, { draft: 0, paid: 1, shipped: 2, cancelled: 3 }, validate: true

  def transition_to!(next_status)
    raise ArgumentError, "#{status} → #{next_status} not allowed" unless
      OrderStatusRegistry.allowed?(status, next_status)
    update!(status: next_status)
  end
end
```

Add a state machine gem only when transitions need guards, callbacks, and an
audit of who moved what. Three states with one legal path do not need one.

### Concerns — and when they're a smell

A good concern is a **role**: `Discardable`, `Publishable`, `Sluggable`. It has
its own tests and could plausibly be a gem.

```ruby
module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, -> { where.not(published_at: nil) }
  end

  def publish! = update!(published_at: Time.current)
  def published? = published_at.present?
end
```

A bad concern is a **filing cabinet**: `UserMethods`, `OrderHelpers`,
`Callbacks` — extracted only to make a fat model file shorter. The complexity
is unchanged, just harder to find. If a concern is used by exactly one class and
isn't a role, it belongs back in the class.

### Safe migrations

The rules that keep a deploy from locking a table:

- Add a column with a default in one migration, backfill in another. Never
  backfill in the same migration that adds the column.
- Add indexes with `algorithm: :concurrently` and `disable_ddl_transaction!`
- Remove a column in two deploys: `ignored_columns` first, then the drop.
- Never rename a column on a live table. Add, dual-write, migrate, drop.

```ruby
class AddIndexToOrders < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :orders, [:user_id, :created_at], algorithm: :concurrently
  end
end
```

### `CurrentAttributes` — a trap, documented

`Current.user` reads beautifully and turns every model into something that
behaves differently depending on invisible request state. Tests pass in isolation
and fail in sequence; jobs get a `nil` where the web process had a user.

Acceptable for exactly two things: request ID for logging, and PaperTrail's
whodunnit. Pass the user as an argument everywhere else.

---

## Rejected patterns

Not neutral omissions — deliberately excluded. If a PR introduces one, it needs
an ADR explaining what changed.

| Pattern | Why not |
|---|---|
| Repository pattern | Fights ActiveRecord. You lose scopes, `includes`, and pagination to gain a swap you will never perform. |
| CQRS / event sourcing | Solves a scale and audit problem this app doesn't have. PaperTrail gives the audit trail for 1% of the cost. |
| Hexagonal / ports & adapters | Rails is already the adapter layer. A second one doubles the file count and halves the greppability. |
| Interactor / organizer chains | Twelve one-method classes to express what one service reads better. Control flow becomes invisible. |
| DI containers | Ruby has `require` and constants. Injection is `def initialize(client: StripeClient.new)`. |
| Serializers for HTML responses | This app renders HTML. Add serializers when a JSON API exists, not before. |
| `accepts_nested_attributes_for` | Use a form object. Nested attributes hide writes in the assignment path and produce error keys nobody can render. |
| Decorators for everything | A component or a helper covers it. `SimpleDelegator` chains defeat `method_missing` debugging. |

---

## The write path, end to end

The patterns compose in one predictable order:

```
Request
  → Controller       parse params, delegate, branch on Result, set status
    → Policy         may this user do this to this record?
    → Form           validate user input, shape it
      → Service      coordinate the write, own the transaction
        → Registry   look up configuration
        → Model      validate, persist, normalize its own attributes
        → Job        enqueue follow-up work after commit
  → View             components + partials render the result
```

Reads take the shorter path: controller → scope or query object → paginate → view.

Anything that jumps a layer — a view calling a service, a model enqueuing mail, a
controller writing three models — is the thing to flag in review.
