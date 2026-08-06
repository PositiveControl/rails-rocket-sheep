# Patterns

The four patterns the template installs, when to reach for each, and when not to.

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
  render :new, status: :unprocessable_entity
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

### The shape

```ruby
module PlanRegistry
  extend RegistryBase

  ITEMS = {
    free: {
      name: "Free",
      price_cents: 0,
      features: %i[basic_access],
      limits: { projects: 3, storage_mb: 100 }
    },
    pro: {
      name: "Pro",
      price_cents: 2900,
      features: %i[basic_access api_access webhooks],
      limits: { projects: 100, storage_mb: 10_000 }
    }
  }.freeze

  class << self
    def items = ITEMS

    def price_cents(type)      = get(type, :price_cents)
    def features(type)         = get(type, :features) || []
    def limit(type, key)       = get(type, :limits)&.dig(key)
    def paid_plans             = items.reject { |_, v| v[:price_cents].zero? }.keys
    def has_feature?(t, f)     = features(t).include?(f.to_sym)
  end
end
```

### What `RegistryBase` provides

| Method | Does |
|---|---|
| `get(type, attribute, level = nil)` | Fetch an attribute; `level` indexes into array attributes, 1-based |
| `exists?(type)` | Whether the key is present |
| `all_types` | All keys |
| `name(type)` | The `:name` attribute, falling back to a titleized key |
| `where { \|type, data\| ... }` | Filter entries |
| `validate!` | Sanity-check the registry; override for custom rules |
| `freeze!` | Deep-freeze items after definition |

Keys are symbolized on lookup, so `get("pro", :price_cents)` and `get(:pro, :price_cents)` behave the same — useful when the value arrives from params.

### Why not a database table

Because these values are code, not data. They're referenced in conditionals, they change with deploys rather than at runtime, and they need to be greppable. A `plans` table means every feature check is a query, and a typo becomes a runtime `nil` instead of a visible constant.

Move it to the database when non-developers need to edit it, or when values must change without a deploy. Until then a registry is faster to read, faster to test, and impossible to get into an inconsistent state.

### The anti-pattern it replaces

```ruby
# BAD — entity knowledge scattered across the codebase
PLANS = { free: 0, pro: 29 }
if user.plan == "pro" || user.plan == "enterprise"
  # ...
end

# GOOD — one source of truth, queried by capability
PlanRegistry.price_cents(user.plan)
PlanRegistry.has_feature?(user.plan, :api_access)
```

Checking capabilities rather than identities is the important half. When a plan is added, capability checks keep working; identity checks silently exclude it.

---

## Soft deletes (Discard)

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

**The trap:** `Post.all` still returns discarded records. Discard does not add a default scope, deliberately — default scopes are notoriously hard to escape. You must use `.kept` where it matters, which means every association and query is a place to forget.

Use soft deletes where restoration is a real requirement — user-generated content, anything with an audit obligation. Use real deletes elsewhere. Every soft-deleted table is a permanent `.kept` tax on every query against it.

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

1. **Controller** parses params, calls a service, renders based on the Result
2. **Service** coordinates, consults registries for configuration, returns `success`/`failure`
3. **Model** validates, and carries `Discard` and `has_paper_trail` where appropriate
4. **Scopes** hold queries — never a class method wrapping a `where`

Keeping to that order is most of what the generated `CLAUDE.md` is enforcing.
