# <%= app_name.titleize %>

Rails 8 application built with the Solid Stack architecture.

## Quick Start

```bash
bin/dev              # Start development server with Tailwind watcher
bin/test             # Run tests (single worker on macOS)
bin/rails console    # Rails console
bin/rails db:migrate # Run migrations
bin/rubocop          # Run linter
bin/brakeman         # Security analysis
```

## Tech Stack

- **Backend:** Rails 8 + PostgreSQL
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS
- **Templates:** Slim (not ERB)
- **Background Jobs:** Solid Queue (database-backed)
- **Caching:** Solid Cache (database-backed)
- **WebSockets:** Solid Cable (database-backed)
- **Auth:** Devise + Petergate
- **Deployment:** Kamal 2 with Docker
- **Linting:** RuboCop with Rails Omakase config
- **Security:** Brakeman static analysis

## Conventions

### Development Workflow

- **Planning:** Create plan file in `docs/plans/` for non-trivial features before coding
- **Collaborative:** Explain findings and reasoning; stop often for feedback
- **TDD:** Write tests before code. Commit when tests are green.
- **TDD Pairing:** Stop when tests fail to present context and discuss next steps
- **Commits:** Small, focused commits with clear messages
- **Documentation:** Update `docs/` when implementing features

### Code Style

- **DRY:** Don't Repeat Yourself. If you see duplicated code, centralize it. Extract helpers, concerns, or services when patterns repeat 2-3 times.
- **Service objects:** Use `ApplicationService` base class with Result pattern
- **Registry pattern:** Single source of truth for config entities (see `app/lib/`)
- **Soft deletes:** Use Discard gem (`include Discard::Model`)
- **Audit trail:** Use PaperTrail gem (`has_paper_trail`)
- **Scopes over class methods:** For all queries

### Database

- **IDs:** UUIDs for all tables (auto-configured)
- **Foreign keys:** Use `t.uuid :parent_id` with `add_foreign_key`
- **Indexing:** Add composite indexes for frequently filtered columns

### Frontend

- **Slim only:** No ERB templates
- **Tailwind:** Utility classes inline
- **Stimulus:** `thing_controller.js` naming convention
- **Generic controllers:** Use `toggle_controller.js` and `modal_controller.js` for common patterns

## Architecture Principles

### DRY - Don't Repeat Yourself

When you notice duplicated code, centralize it:

```ruby
# BAD: Same validation logic in multiple places
class OrdersController
  def create
    return render_error("Invalid amount") if params[:amount] <= 0
    # ...
  end
end

class RefundsController
  def create
    return render_error("Invalid amount") if params[:amount] <= 0
    # ...
  end
end

# GOOD: Extract to a concern or service
module AmountValidation
  extend ActiveSupport::Concern

  included do
    before_action :validate_positive_amount, only: [:create, :update]
  end

  private

  def validate_positive_amount
    return if params[:amount].to_f > 0
    render_error("Invalid amount")
  end
end
```

**When to extract:**
- Same code appears 2-3 times → Extract to helper/concern/service
- Similar patterns across models → Create a shared concern
- Repeated view logic → Create a helper method or partial
- Complex conditionals → Extract to a policy or service object

### Service Objects

Use `ApplicationService` for business logic:

```ruby
class CreateOrderService < ApplicationService
  def initialize(user:, items:)
    @user = user
    @items = items
  end

  def call
    order = Order.new(user: @user)
    order.items = @items

    if order.save
      success(order)
    else
      failure(order.errors.full_messages)
    end
  end
end

# Usage:
result = CreateOrderService.call(user: current_user, items: cart_items)
if result.success?
  redirect_to result.value  # result.value is the order
else
  flash[:alert] = result.errors.join(", ")
end
```

### Registry Pattern

Use registries for configuration entities (plans, product types, etc.):

```ruby
# app/lib/plan_registry.rb
module PlanRegistry
  extend RegistryBase

  ITEMS = {
    free: { name: "Free", price: 0, features: [:basic] },
    pro: { name: "Pro", price: 29, features: [:basic, :api, :support] }
  }.freeze

  class << self
    def items = ITEMS
    def price(type) = get(type, :price)
    def has_feature?(type, feature) = get(type, :features)&.include?(feature)
  end
end

# Usage:
PlanRegistry.price(:pro)              # => 29
PlanRegistry.has_feature?(:pro, :api) # => true
```

### Anti-Patterns to Avoid

```ruby
# BAD: Hardcoded entity knowledge in service
PLANS = { free: 0, pro: 29 }

# GOOD: Query registry for capabilities
PlanRegistry.price(plan_type)

# BAD: N+1 queries - iterating without preload
users.each { |u| u.orders.count }

# GOOD: Eager load or use counter cache
User.includes(:orders).each { |u| u.orders.size }

# BAD: Early .to_a forcing evaluation then filtering
User.where(active: true).to_a.select { |u| u.admin? }

# GOOD: Filter in database
User.where(active: true).where(role: :admin)

# BAD: Ruby sorting large datasets
users.to_a.sort_by { |u| u.orders.count }

# GOOD: Database sorting
User.left_joins(:orders).group(:id).order("COUNT(orders.id) DESC")

# BAD: Duplicated code across controllers/models
# (see DRY section above)

# GOOD: Extract to concerns, helpers, or services
```

### Slim Template Pitfalls

```slim
/ Tailwind brackets conflict with Slim - use class=""
div class="max-h-[85vh]"

/ Text starting with ( needs span wrapper
span.count = "(#{count})"

/ Multi-line Ruby needs ruby: block
ruby:
  config = {
    foo: { label: "Foo" },
    bar: { label: "Bar" }
  }

/ Dynamic attributes need local variables
- path = "/items/#{item.id}"
a href=path
```

## Testing

### Running Tests

```bash
bin/test                    # All tests
bin/test test/models/       # Directory
bin/test test/models/user_test.rb:42  # Specific line
```

### Test Patterns

```ruby
# Service test
class CreateOrderServiceTest < ActiveSupport::TestCase
  test "creates order with valid items" do
    user = users(:one)
    items = [{ product_id: products(:widget).id, quantity: 2 }]

    result = CreateOrderService.call(user: user, items: items)

    assert result.success?
    assert_equal user, result.value.user
  end

  test "fails with empty items" do
    result = CreateOrderService.call(user: users(:one), items: [])

    assert result.failure?
    assert_includes result.errors, "Items can't be empty"
  end
end

# VCR for external API calls
class ExternalApiTest < ActiveSupport::TestCase
  test "fetches data from external API" do
    vcr_cassette("external_api/fetch_data") do
      result = ExternalApi.fetch_data

      assert result.present?
    end
  end
end
```

### Debugging

```ruby
# In any file
binding.pry  # Drops into debugger

# Common pry commands
# next          - Step over
# step          - Step into
# continue      - Continue execution
# whereami      - Show current location
# ls            - List available methods/variables
```

## Deployment

### Kamal Setup

1. Configure `config/deploy.yml` with your server details
2. Set up secrets in `.kamal/secrets`
3. Run `kamal setup` to provision server
4. Run `kamal deploy` to deploy

### Environment Variables

Required for production:
- `RAILS_MASTER_KEY` - Rails credentials key
- `DATABASE_URL` - PostgreSQL connection string
- `POSTGRES_PASSWORD` - Database password

## Key Documentation

| Topic | File |
|-------|------|
| Models | `docs/models.md` |
| Design Patterns | `docs/design-patterns.md` |
| Architecture Decisions | `docs/architecture.md` |
| How-To Guides | `docs/how-tos/` |

## Project Structure

```
app/
├── lib/                    # Registries and config modules
├── models/                 # ActiveRecord models
├── services/               # Service objects (inherit ApplicationService)
├── controllers/            # RESTful controllers
├── jobs/                   # Background jobs (Solid Queue)
├── helpers/                # View helpers
├── views/                  # Slim templates
└── javascript/controllers/ # Stimulus controllers

docs/
├── models.md               # Model documentation
├── design-patterns.md      # UI/UX patterns
├── architecture.md         # Architecture Decision Records
├── how-tos/                # Step-by-step guides
├── synthesis/              # Feature analysis
└── plans/                  # Implementation plans
```
