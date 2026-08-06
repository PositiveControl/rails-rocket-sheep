# Patterns

The patterns the template installs, when to reach for each, and when not to.

The generated app carries its own reference: `docs/system/design-patterns.md` for the
backend (controllers, services, forms, queries, policies, jobs, caching) and
`docs/system/ui-patterns.md` for the view layer. This page covers the base classes the
template ships.

---

## Service objects

`ApplicationService` gives business logic a consistent home and a consistent return type.

### The shape

```ruby
class CreateOrderService < ApplicationService
  def initialize(user:, items:)
    @user  = user
    @items = items
  end

  def call
    return failure("Items can't be empty") if @items.empty?

    order = Order.new(user: @user)
    order.items = @items

    if order.save
      log_info("Order created", order_id: order.id)
      success(order)
    else
      failure(order.errors.full_messages)
    end
  end
end
```

`self.call(...)` forwards to `new(...).call`, so callers write:

```ruby
result = CreateOrderService.call(user: current_user, items: cart_items)

if result.success?
  redirect_to result.value, notice: "Order placed"
else
  flash.now[:alert] = result.errors.join(", ")
  render :new, status: :unprocessable_content
end
```

### The Result type

A `Struct` with four members and two predicates:

| Member | Meaning |
|---|---|
| `success?` | Operation succeeded |
| `failure?` | Inverse of the above |
| `value` | The thing produced, or `nil`. Aliased as `record`. |
| `errors` | Array of message strings. Empty on success. |

`failure("a string")` wraps into an array automatically, so `result.errors` is always an array.

### Logging helpers

`log_info` and `log_error` tag output with the service class name:

```ruby
log_error("Payment declined", order_id: order.id, code: response.code)
# => [ProcessPaymentService] Payment declined
```

### When to use a service

- The operation touches more than one model
- The operation has a meaningful failure mode the caller must handle
- The logic is called from more than one place — controller and job, say
- The operation would otherwise make a controller action longer than about ten lines

### When not to

- **Single-model validation.** That's a model concern.
- **A one-line query.** That's a scope.
- **Pure formatting.** That's a helper or a presenter.
- **A wrapper around one `create!` call.** A service that only calls `Model.create!` adds a file and a layer for nothing.

The failure mode of this pattern is service objects for everything, producing forty single-method classes that each wrap one line. Reach for it when there's genuine coordination or a genuine failure path.

### Exceptions vs failures

Return `failure()` for expected outcomes — validation errors, business rule violations, a declined card. Raise for genuinely exceptional conditions, and define the exception on the service:

```ruby
class TransferFundsService < ApplicationService
  class InsufficientFundsError < StandardError; end

  def call
    raise InsufficientFundsError if @from.balance < @amount
    # ...
  end
end
```

Rule of thumb: if the controller should render a form again, it's a `failure`. If something is broken, raise.

---

## Registries

For entities with a fixed set of variants, each carrying attributes: plans, tiers, roles, product types, difficulty levels.

`app/lib/plan_registry.rb` ships as the canonical shape — copy the file when you need another one.

### The shape

```ruby
module PlanRegistry
  # Nested under the module on purpose: Zeitwerk expects plan_registry.rb to
  # define PlanRegistry and anything inside it. A top-level `Plan` here would
  # raise on eager load in production.
  Plan = Data.define(:key, :name, :price_cents, :interval, :features, :limits) do
    def free?                 = price_cents.zero?
    def has_feature?(feature) = features.include?(feature.to_sym)
    def limit(name)           = limits[name.to_sym]
  end

  ITEMS = {
    free: Plan.new(key: :free, name: "Free", price_cents: 0, interval: :month,
                   features: %i[basic_access], limits: { projects: 3, storage_mb: 100 }),
    pro:  Plan.new(key: :pro, name: "Pro", price_cents: 2_900, interval: :month,
                   features: %i[basic_access api_access webhooks],
                   limits: { projects: 100, storage_mb: 10_000 })
  }.freeze

  class << self
    def [](key)   = ITEMS.fetch(key.to_sym)
    def find(key) = ITEMS[key.to_sym]
    def all       = ITEMS.values
    def keys      = ITEMS.keys
    def exists?(key) = ITEMS.key?(key.to_sym)
    def paid      = all.reject(&:free?)
    def with_feature(feature) = all.select { |plan| plan.has_feature?(feature) }
  end
end
```

```ruby
PlanRegistry[:pro].price_cents                     # => 2900
PlanRegistry[:pro].has_feature?(:webhooks)         # => true
PlanRegistry[user.plan].limit(:projects)           # => 100
PlanRegistry.paid.map(&:name)                      # => ["Pro"]
PlanRegistry[:nope]                                # raises KeyError
```

### Why `Data`, and why `fetch`

Three properties, each preventing a specific failure:

| Choice | Prevents |
|---|---|
| `Data` entries, not hashes | `entry[:price_cnts]` returning `nil` and surfacing as a blank in a view. A typo is `NoMethodError` at the call site. |
| Behaviour on the entry (`free?`, `has_feature?`) | Every caller reimplementing `price_cents.zero?`, then one of them getting it wrong |
| `fetch` for lookup | An unknown key silently becoming `nil`. Use `find` where a miss is legitimate — a key arriving from params. |

`Data.define` also requires every member at construction. Add an attribute to one
variant and Ruby raises `ArgumentError: missing keyword` for the others — you can't
half-migrate a registry.

There is no base class. An earlier version of this template shipped a `RegistryBase`
module with a `get(type, attribute, level)` accessor; it was 113 lines of bespoke API
that every agent and every new developer had to learn, and it made typos return `nil`.
Plain Ruby does the job with less to explain.

### Query capabilities, not identities

```ruby
# BAD — entity knowledge scattered across the codebase
PLANS = { free: 0, pro: 29 }
if user.plan == "pro" || user.plan == "enterprise"
  # ...
end

# GOOD — one source of truth, queried by capability
PlanRegistry[user.plan].price_cents
PlanRegistry[user.plan].has_feature?(:api_access)
```

This is the half that matters. When a plan is added, capability checks keep working;
identity checks silently exclude it.

### Why not a database table

Because these values are code, not data. They're referenced in conditionals, they change with deploys rather than at runtime, and they need to be greppable. A `plans` table means every feature check is a query, and a typo becomes a runtime `nil` instead of a visible constant.

Move it to the database when non-developers need to edit it, or when values must change without a deploy. Until then a registry is faster to read, faster to test, and impossible to get into an inconsistent state.

### What isn't a registry

Constants with no variants — branding strings, upload limits, session timeouts. Those
are frozen constants in `app/lib/app_config.rb`. A registry is specifically for *a
fixed set of variants that each carry the same attributes*.

---

## Form objects

`ApplicationForm` is `ActiveModel::Model` plus `ActiveModel::Attributes`, a `persisted?`
that returns false, a `save` that subclasses must implement, and `promote_errors` for
copying a failed record's errors onto the form.

### The shape

```ruby
class SignupForm < ApplicationForm
  attribute :email,        :string
  attribute :company_name, :string
  attribute :accept_terms, :boolean, default: false

  validates :email, :company_name, presence: true
  validates :accept_terms, acceptance: true

  attr_reader :user

  def save
    return false if invalid?

    ApplicationRecord.transaction do
      company = Company.create!(name: company_name)
      @user   = company.users.create!(email:, role: :owner)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    promote_errors(e.record)
    false
  end
end
```

The controller treats it exactly like a model, which is the point:

```ruby
if @form.save
  redirect_to dashboard_path, notice: "Welcome"
else
  render :new, status: :unprocessable_content
end
```

In the view, pass an explicit `url:` — a form object has no routes:

```slim
= form_with model: @form, url: signup_path do |f|
  = render ErrorSummaryComponent.new(record: @form)
```

### When to use one

- One submit writes to two or more models
- The form has fields that aren't columns (`accept_terms`, `confirm_email`)
- A wizard step needs partial validation
- The same model needs different rules in two contexts

### When not to

When the form maps to a single model. `form_with model: @order` already does that job.

### Why not `accepts_nested_attributes_for`

It hides writes inside a model's assignment path, produces error keys shaped like
`items.attributes.0.quantity` that no view can render sensibly, and makes it impossible
to validate the submission as a whole. A form object is more code and less magic.

### Form object vs. service

The form owns validation and the shape of user input; a service owns coordination. A
form may call a service. A service never knows a form exists.

---

## Components (ViewComponent)

`ApplicationComponent` inherits `ViewComponent::Base` and adds `class_names`. Generation
is configured for Slim sidecar directories:

```bash
bin/rails generate component Alert message
# app/components/alert_component.rb
# app/components/alert_component/alert_component.html.slim
# test/components/alert_component_test.rb
```

Four components ship, and each is a worked example of one rule:

| Component | Demonstrates |
|---|---|
| `AlertComponent` | Variants as a frozen hash; `render?` for "nothing to say" |
| `FlashComponent` | Composition — renders `AlertComponent` per message; state passed in, not read from the view context |
| `ErrorSummaryComponent` | Duck-typed input — works with a model or an `ApplicationForm` |
| `EmptyStateComponent` | Slots (`renders_one :action`) |

### The rules

- Everything the template needs arrives through `initialize`. A component never reads
  `params`, `session`, or `current_user` on its own — that's what makes it renderable in
  a test with no request.
- Template logic lives in private methods, not in the `.slim` file.
- Variants are a frozen hash. Full Tailwind class names must appear literally in Ruby or
  Slim source or the compiler purges them.
- Every component gets a unit test. They're the cheapest view tests available.

### When not to

A one-off block of markup on one page. Write it inline, or as a partial with strict
locals. A component with one caller and no logic costs three files and buys nothing.

---

## Deletes and soft deletes (Discard)

`destroy` is the default. Discard is installed, but soft deletion is a per-table
decision rather than a house style.

```ruby
class Post < ApplicationRecord
  include Discard::Model
end

post.discard      # sets discarded_at
post.undiscard    # clears it
Post.kept         # not discarded
Post.discarded    # discarded
```

Add the column in a migration:

```ruby
add_column :posts, :discarded_at, :datetime
add_index  :posts, :discarded_at
```

### When it earns its place

- Restoration is a feature the user can reach, not a console task
- An audit obligation requires the row to survive
- Foreign keys point at the row from records that must stay valid

### The trap

`Post.all` still returns discarded records. Discard adds no default scope,
deliberately — default scopes are notoriously hard to escape. That means every
query, every association, and every authorization check against a discardable
model is a place to forget `.kept`, and forgetting is silent. The cost is
permanent and it applies to code written years later.

### Check PaperTrail first

PaperTrail is already installed and can restore a destroyed record:

```ruby
version = PaperTrail::Version.where(item_type: "Post", item_id: id, event: "destroy").last
post = version.reify
post.save!
```

That covers "an admin deleted the wrong thing" without taxing every future query
against the table. It does not restore associations, and it does not keep foreign
keys valid between the destroy and the restore — when those matter, use Discard.

---

## Audit trail (PaperTrail)

Installed with `--with-changes`, so diffs are queryable rather than just serialized blobs.

```ruby
class Order < ApplicationRecord
  has_paper_trail
end

order.versions              # every change
order.versions.last.changeset  # what changed, as a hash
order.paper_trail.previous_version
```

To record who made the change, set the whodunnit in `ApplicationController`:

```ruby
before_action :set_paper_trail_whodunnit
```

**Cost:** a row in `versions` for every create, update, and destroy on tracked models. On a high-write table that grows quickly. Track models where history has value — orders, permissions, financial records — not every model you own.

Limit what's stored on noisy models:

```ruby
has_paper_trail only: [:status, :total_cents]
```

---

## Combining them

The patterns compose in a predictable order. A typical write path:

1. **Controller** parses params, calls a form or service, renders based on the result
2. **Form** validates user input and shapes it, when the submit spans models
3. **Service** coordinates, consults registries for configuration, returns `success`/`failure`
4. **Model** validates, and carries `Discard` and `has_paper_trail` where appropriate
5. **Scopes** hold queries — never a class method wrapping a `where`
6. **Components** render the result

Keeping to that order is most of what the generated `CLAUDE.md` is enforcing.
