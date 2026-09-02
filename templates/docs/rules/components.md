---
id: components
title: ViewComponent — shape, slots, variants, tests
applies_to: ["app/components/**/*.rb", "app/components/**/*.slim", "test/components/**/*.rb"]
triggers: ["ViewComponent", "component", "ApplicationComponent", "render_inline", "renders_one", "renders_many", "slots", "render?", "sidecar", "generate component", "AlertComponent", "variants"]
see_also: ["view-code-placement", "partials", "tailwind-build", "registries"]
tokens: 1110
current_state: matches
---

# ViewComponent

Components live in `app/components`, class names end in `Component`, modules are
plural like controllers (`Orders::RowComponent`).

**Name for the output, not the input:** `AvatarComponent`, not `UserComponent`.

## Generating

```bash
bin/rails generate component Alert message           # slim template, sidecar dir
# long form, if the alias is shadowed: bin/rails generate view_component:component Alert message
```

Produces:

```
app/components/alert_component.rb
app/components/alert_component/alert_component.html.slim
test/components/alert_component_test.rb
```

Sidecar directories are on by default, so a component's Ruby, template, and any
component-scoped Stimulus controller sit in one folder.

## The shape

`AlertComponent` ships with the app and is the reference implementation:

```ruby
# app/components/alert_component.rb
class AlertComponent < ApplicationComponent
  VARIANTS = {
    notice:  "bg-blue-50 border-blue-200 text-blue-800 dark:...",
    success: "bg-green-50 border-green-200 text-green-800 dark:...",
    warning: "bg-yellow-50 border-yellow-200 text-yellow-900 dark:...",
    alert:   "bg-red-50 border-red-200 text-red-800 dark:..."
  }.freeze

  DEFAULT_VARIANT = :notice

  def initialize(variant: DEFAULT_VARIANT)
    @variant = variant.to_sym
  end

  def render? = content.present?

  private

  def classes
    class_names("rounded border px-4 py-3 text-sm", VARIANTS.fetch(@variant, VARIANTS[DEFAULT_VARIANT]))
  end
end
```

```slim
/ app/components/alert_component/alert_component.html.slim
div class=classes role="alert"
  = content
```

Three more ship with it: `FlashComponent` (renders the flash as alerts, already in
the layout), `ErrorSummaryComponent` (validation errors for a model or form
object), and `EmptyStateComponent` (the empty-collection state, with an action slot).

## Rules

- **Everything the template needs is a private method or an ivar set in
  `initialize`.** A component never reads `params`, `session`, or `current_user`
  from thin air — pass them in. That's what makes it testable in isolation.
- **`render?`** for "should this appear at all". Beats an `- if` wrapped around the
  render call at every call site.
- **Slots over positional arguments** when a component takes markup:

  ```ruby
  class CardComponent < ApplicationComponent
    renders_one :header
    renders_one :footer
    renders_many :actions
  end
  ```

  ```slim
  = render CardComponent.new do |card|
    - card.with_header do
      h2.text-lg.font-semibold Order #1234
    - card.with_action do
      = link_to "Edit", edit_order_path(@order)
    p Body content goes in the default content slot.
  ```

- **Variants are a frozen hash, not a chain of conditionals.** Same reason
  [registries](registries.md) exist: one place to add the next variant. Full
  Tailwind class names must appear literally — see [tailwind-build](tailwind-build.md).
- **Every component gets a test.** The cheapest view tests available — no request,
  no routing, no fixtures beyond what you pass in.

  ```ruby
  class AlertComponentTest < ViewComponent::TestCase
    test "renders nothing without content" do
      render_inline(AlertComponent.new)
      assert_no_selector "[role=alert]"
    end

    test "applies the success variant" do
      render_inline(AlertComponent.new(variant: :success)) { "Saved" }
      assert_selector "[role=alert].bg-green-50", text: "Saved"
    end
  end
  ```

## When not to

A one-off block of markup used once on one page. Write it inline. Components pay
for themselves through reuse and testing; a component with one caller and no logic
is a [partial](partials.md) that costs three files.

Rationale and consequences: [ADR 0006](../adr/0006-viewcomponent-for-ui-units.md).
