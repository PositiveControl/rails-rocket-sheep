# UI Patterns

View-layer patterns: Slim, ViewComponent, partials, Turbo, Stimulus, Tailwind.

Backend patterns — controllers, services, forms, queries, jobs, caching — live in
[`design-patterns.md`](design-patterns.md).

---

## Where view code goes

Four places, in order of preference. Pick the first one that fits.

| | Use for | Test |
|---|---|---|
| **Component** (`app/components/`) | A UI unit with markup + logic + variants, used in >1 place | Unit test, renders in isolation |
| **Partial** (`app/views/**/_x.html.slim`) | Markup reused inside one resource, no logic | Covered by the view's test |
| **Helper** (`app/helpers/`) | Stateless formatting: a date, a currency, a class string | Plain unit test |
| **Inline** | Used once, under ~10 lines | The page test |

**The dividing line between partial and component:** does it take logic? A partial
that starts with three `- if` lines and a class-string calculation is a component
that hasn't been written yet. A component with no logic and one caller is a partial
with extra ceremony.

**Helpers stay stateless.** A helper that takes a record and returns markup is a
component. A helper that formats a value is a helper.

---

## ViewComponent

Components live in `app/components`, class names end in `Component`, modules are
plural like controllers (`Orders::RowComponent`).

**Name for the output, not the input:** `AvatarComponent`, not `UserComponent`.

### Generating

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

Sidecar directories are configured on by default, so a component's Ruby, template,
and any component-scoped Stimulus controller sit in one folder.

### The shape

`AlertComponent` ships with the app and is the reference implementation:

```ruby
# app/components/alert_component.rb
class AlertComponent < ApplicationComponent
  VARIANTS = {
    notice: "bg-blue-50 border-blue-200 text-blue-800 dark:...",
    success: "bg-green-50 border-green-200 text-green-800 dark:...",
    warning: "bg-yellow-50 border-yellow-200 text-yellow-900 dark:...",
    alert: "bg-red-50 border-red-200 text-red-800 dark:..."
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

```slim
= render AlertComponent.new(variant: :success) do
  | Order placed.
```

Three more ship with it: `FlashComponent` (renders the flash as alerts, already in the
layout), `ErrorSummaryComponent` (validation errors for a model or form object), and
`EmptyStateComponent` (the empty-collection state, with an action slot).

### Rules

- **Everything the template needs is a private method or an ivar set in
  `initialize`.** A component never reads `params`, `session`, or `current_user`
  from thin air — pass them in. That's what makes it testable in isolation.
- **`render?`** for "should this appear at all". Beats an `- if` wrapped around
  the render call at every call site.
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
  registries exist: one place to add the next variant.
- **Every component gets a test.** They're the cheapest view tests available —
  no request, no routing, no fixtures beyond what you pass in.

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

### When not to use a component

A one-off block of markup used once on one page. Write it inline. Components pay
for themselves through reuse and testing; a component with one caller and no logic
is a partial that costs three files.

---

## Partials

Still the right tool for markup reused within one resource. Two rules make them safe.

### Strict locals, always

Without them, a partial silently reads instance variables from whatever rendered
it, and a typo'd local is `nil` instead of an error.

In Slim, the magic comment must be the first line and must be written exactly
this way — Rails matches it with a regex, so spacing matters:

```slim
/# locals: (order:, compact: false)
.rounded.border.p-4
  = order.reference
  - unless compact
    p.text-sm.text-gray-600 = order.placed_at.to_fs(:long)
```

```slim
= render "orders/order", order: @order, compact: true
```

An undeclared local now raises at render time instead of rendering blank.

**Note:** strict locals apply to partials only — files whose names start with `_`.

### No instance variables in partials

```slim
/ BAD — partial is now welded to one controller
h2 = @order.reference

/ GOOD — everything arrives as a declared local
/# locals: (order:)
h2 = order.reference
```

### Collection rendering

```slim
= render partial: "orders/order", collection: @orders, as: :order
```

One template compile for the whole collection, and each iteration gets
`order_counter` and `order_iteration` for free.

---

## Turbo

### Frames

A frame scopes navigation to a region. Give it a stable id via `dom_id`.

```slim
= turbo_frame_tag dom_id(order) do
  = render OrderRowComponent.new(order:)
```

The server must respond with a matching frame or Turbo drops the response and
logs a console error. Any link inside a frame targets that frame unless told
otherwise:

```slim
= link_to "Full page", order_path(order), data: { turbo_frame: "_top" }
```

**Lazy frames** for expensive sections — the page paints, then the frame loads:

```slim
= turbo_frame_tag "order_history", src: order_history_path(order), loading: :lazy do
  = render SpinnerComponent.new
```

### Streams: from the controller by default

```ruby
def create
  result = CreateCommentService.call(post: @post, user: current_user, body: comment_params[:body])

  if result.success?
    respond_to do |format|
      format.turbo_stream   # renders create.turbo_stream.slim
      format.html { redirect_to @post }
    end
  else
    render :new, status: :unprocessable_content
  end
end
```

```slim
/ app/views/comments/create.turbo_stream.slim
= turbo_stream.append "comments" do
  = render CommentComponent.new(comment: @comment)
= turbo_stream.update "comment_form" do
  = render CommentFormComponent.new(post: @post, comment: Comment.new)
```

**Always keep the `format.html` branch.** It's what makes the feature work
without JavaScript, and it's what the system test exercises.

### Broadcasting from models: the main Hotwire footgun

```ruby
# BAD — every save pushes to every subscriber, forever
class Comment < ApplicationRecord
  broadcasts_to :post
end
```

That renders and pushes on every create, update, and destroy — including
backfills, imports, and console fixes. It renders in a context with no
`current_user`, so anything user-specific in the partial is wrong for someone.

Model broadcasts are for **genuine multi-user push**: a shared board, a live
feed, a chat. Even then, broadcast from an `after_commit` in a job, not inline,
so a slow render doesn't sit inside the request:

```ruby
after_commit :broadcast_later, on: :create

def broadcast_later
  BroadcastCommentJob.perform_later(id)
end
```

For "the person who clicked should see the result" — the overwhelmingly common
case — that's a controller stream response, not a broadcast.

### Morphing and scroll preservation

For pages that refresh in place (dashboards, filters):

```slim
/ in the layout head
meta name="turbo-refresh-method" content="morph"
meta name="turbo-refresh-scroll" content="preserve"
```

Morphing keeps focus and scroll on refresh. It also means DOM state a Stimulus
controller set can be reverted — use `data-turbo-permanent` on elements that
must survive.

---

## Stimulus

Controllers named `thing_controller.js`. Two generic ones ship with the app:
`toggle_controller.js` and `modal_controller.js`. Reach for those before writing
a new one.

### The contract

```javascript
// app/javascript/controllers/character_counter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values  = { max: Number }
  static classes = ["warning"]

  connect() { this.update() }

  update() {
    const remaining = this.maxValue - this.inputTarget.value.length
    this.countTarget.textContent = remaining
    this.countTarget.classList.toggle(this.warningClass, remaining < 10)
  }
}
```

```slim
div data-controller="character-counter" data-character-counter-max-value="280" \
    data-character-counter-warning-class="text-red-500"
  textarea data-character-counter-target="input" data-action="input->character-counter#update"
  span data-character-counter-target="count"
```

**Rules:**

- **Targets, values, classes — never `document.querySelector`.** A controller
  that reaches outside its own element breaks the moment Turbo replaces the DOM.
- **No Tailwind class strings in JavaScript.** Pass them as `static classes` so
  the Tailwind compiler can see them in the template. Classes only present in a
  `.js` file get purged from the build.
- **The server owns truth, the controller owns feel.** Anything that must persist
  goes through a form or a `fetch` to a real controller action, not into
  `localStorage`.
- **Idempotent `connect()`.** It runs on every Turbo navigation, cache preview,
  and morph. Clean up in `disconnect()` — timers, listeners, observers.
- **Component-scoped controllers** live in the component's sidecar directory when
  they exist only for that component.

---

## Slim gotchas

Slim's terseness collides with Tailwind's bracket syntax in specific, repeatable
ways. These are the ones that bite.

### Bracket values need `class=""`

```slim
/ BAD: Slim parses [85vh] as attributes
div.max-h-[85vh]

/ GOOD
div class="max-h-[85vh]"
div class="max-h-[85vh] w-[calc(100%-2rem)] grid-cols-[1fr_2fr]"

/ Same for arbitrary properties and variants
div class="[--my-var:10px] [&>*]:mt-4 [&:nth-child(2)]:bg-blue-500"
```

### Text on its own line needs a pipe

```slim
/ BAD: parsed as an element
div.pr-4
  Some text here

/ GOOD
div.pr-4
  | Some text here

/ Or inline
div.pr-4 Some text here

/ Dynamic
div.pr-4 = user.name
```

### Text starting with a special character

```slim
/ BAD: ( is read as Ruby
span.count
  (5 items)

/ GOOD
span.count
  | (5 items)

/ GOOD
span.count = "(#{count} items)"
```

### Multi-line Ruby needs a `ruby:` block

Each `-` line is evaluated independently, so a multi-line hash fails silently.

```slim
/ BAD
- config = {
-   foo: "bar"
- }

/ GOOD
ruby:
  config = {
    foo: "bar",
    baz: "qux"
  }
```

### Interpolation in attributes needs a local first

```slim
/ BAD: loop variable not resolved
- items.each do |item|
  a href="/items/#{item.id}"

/ GOOD
- items.each do |item|
  - path = "/items/#{item.id}"
  a href=path

/ BEST: a route helper
- items.each do |item|
  a href=item_path(item)
```

Same for dynamic classes:

```slim
- color_class = "text-#{type}-500"
div class=color_class

/ Or array syntax
div class=["text-#{type}-500", "font-bold"]
```

---

## Tailwind

### Semantic colors

| Purpose | Class | Use |
|---|---|---|
| Primary | `blue-500` | Primary actions, links |
| Success | `green-500` | Confirmations |
| Warning | `yellow-500` | Caution states |
| Danger | `red-500` | Errors, destructive actions |
| Info | `cyan-500` | Informational messages |

Semantic meaning lives in a component's `VARIANTS` hash, not scattered across
templates. When the palette changes, one hash changes.

### Dark mode

Every surface and text color needs its dark counterpart. Miss one and the page is
unreadable in dark mode for exactly the users who never report it.

```slim
.bg-white.dark:bg-gray-800.rounded-lg.shadow.p-6
  h3.text-lg.font-semibold.text-gray-900.dark:text-gray-100 Card title
  p.text-gray-600.dark:text-gray-300 Body copy
```

### Responsive

Mobile-first — unprefixed classes are the small screen, prefixes add up from there.

```slim
.grid.grid-cols-1.sm:grid-cols-2.lg:grid-cols-4.gap-4
```

| Prefix | Min width | Target |
|---|---|---|
| `sm:` | 640px | Tablet portrait |
| `md:` | 768px | Tablet landscape |
| `lg:` | 1024px | Desktop |
| `xl:` | 1280px | Large desktop |

### Only literal class names survive the build

Tailwind scans source text. A class assembled at runtime does not exist in the CSS.

```slim
/ BAD — text-green-500 is never generated
- div class="text-#{status}-500"

/ GOOD — full class names appear literally in the source
- STATUS_CLASSES = { ok: "text-green-500", failed: "text-red-500" }
- div class=STATUS_CLASSES[status]
```

---

## Forms

`form_with` against a model or a form object. Error display is a component so it
looks the same everywhere.

```slim
= form_with model: @order do |f|
  = render ErrorSummaryComponent.new(record: @order)

  .mb-4
    = f.label :email, class: "block text-sm font-medium text-gray-700 mb-1"
    = f.email_field :email, class: "w-full border rounded px-3 py-2"
    - if @order.errors[:email].any?
      p.text-red-500.text-sm.mt-1 = @order.errors.full_messages_for(:email).first

  = f.submit "Save", class: "bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded"
```

The controller must render failures with a 422 or Turbo discards the response and
the form appears frozen — see the status contract in
[`design-patterns.md`](design-patterns.md#the-turbo-status-contract).

---

## Empty states

Every collection view has three states, and the second one is the one people
forget. A list that renders nothing when empty reads as a broken page.

```slim
- if @orders.any?
  = render partial: "orders/order", collection: @orders, as: :order
  == pagy_nav(@pagy)
- else
  = render EmptyStateComponent.new(
      title: "No orders yet",
      description: "Orders appear here once a customer checks out.",
      action: link_to("New order", new_order_path, class: "..."))
```

---

## Accessibility

Non-negotiable, and cheap when done as you go:

- Semantic HTML — `button` for actions, `a` for navigation. A clickable `div` is
  invisible to keyboard and screen reader users.
- `aria-label` on icon-only buttons.
- 4.5:1 contrast minimum — check both themes.
- Every interactive element reachable and operable by keyboard; ESC closes
  modals (`modal_controller.js` handles this).
- Focus stays visible. Never `outline: none` without a replacement.
- Form inputs have a `label` with a matching `for`, not just a placeholder.

---

## Helpers that ship

```slim
= progress_bar(current: 75, max: 100, label: "Progress", show_percentage: true)
= capacity_bar(current: 8, max: 10, label: "Storage")
= jsonld_tag(schema_hash)
```

See `app/helpers/` for the full signatures.
