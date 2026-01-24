# Design Patterns

UI/UX patterns and component guidelines.

## Slim + Tailwind Gotchas

### Custom Values with Brackets

Tailwind's bracket syntax (e.g., `max-h-[85vh]`) conflicts with Slim's attribute parsing. Always use `class=""` for custom values:

```slim
/ BAD: Slim interprets brackets as attributes
div.max-h-[85vh]

/ GOOD: Use class="" for bracket values
div class="max-h-[85vh]"

/ Also works with multiple classes
div class="max-h-[85vh] w-[calc(100%-2rem)] grid-cols-[1fr_2fr]"
```

### Text on New Lines

Text directly after an element on a new line can cause parse errors. Use `|` pipe on a new line:

```slim
/ BAD: Parse error - text interpreted as element
div.pr-4
  Some text here

/ GOOD: Use pipe for text content
div.pr-4
  | Some text here

/ GOOD: Or inline the text
div.pr-4 Some text here

/ For dynamic content, use =
div.pr-4
  = @user.name
```

### Text Starting with Special Characters

Text starting with `(`, `[`, `{`, or other special characters needs escaping:

```slim
/ BAD: Slim interprets ( as Ruby code
span.count
  (5 items)

/ GOOD: Use pipe or wrap in span
span.count
  | (5 items)

/ GOOD: Or use interpolation
span.count = "(#{count} items)"
```

### Multi-line Ruby Code

Each `-` line in Slim is evaluated independently. Multi-line hashes/arrays fail silently:

```slim
/ BAD: Multi-line hash breaks silently
- config = {
-   foo: "bar",
-   baz: "qux"
- }

/ GOOD: Use ruby: block for multi-line Ruby
ruby:
  config = {
    foo: "bar",
    baz: "qux"
  }

/ Then use config in your template
- config.each do |key, value|
  div = "#{key}: #{value}"
```

### Dynamic Attributes with Interpolation

Slim can't resolve loop variables in inline interpolation within attributes:

```slim
/ BAD: Variable not resolved in attribute interpolation
- items.each do |item|
  a href="/items/#{item.id}"

/ GOOD: Assign to local variable first
- items.each do |item|
  - item_path = "/items/#{item.id}"
  a href=item_path

/ GOOD: Or use Rails helpers
- items.each do |item|
  a href=item_path(item)
```

### Dynamic CSS Classes

Same issue applies to dynamic Tailwind classes:

```slim
/ BAD: Interpolation in class attribute
- type = "success"
div class="text-#{type}-500"

/ GOOD: Build class string first
- type = "success"
- color_class = "text-#{type}-500"
div class=color_class

/ GOOD: Or use array syntax
div class=["text-#{type}-500", "font-bold"]
```

### Tailwind Arbitrary Properties

For Tailwind's arbitrary property syntax, always quote:

```slim
/ Custom CSS properties
div class="[--my-var:10px]"
div class="[mask-type:luminance]"

/ Arbitrary variants
div class="[&>*]:mt-4"
div class="[&:nth-child(2)]:bg-blue-500"
```

---

## Color System

### Semantic Colors

| Purpose | Tailwind Class | Usage |
|---------|---------------|-------|
| Primary | `blue-500` | Primary actions, links |
| Success | `green-500` | Success states, confirmations |
| Warning | `yellow-500` | Warnings, caution states |
| Danger | `red-500` | Errors, destructive actions |
| Info | `cyan-500` | Informational messages |

### Dark Mode

Use Tailwind's dark mode classes:

```slim
div.bg-white.dark:bg-gray-800
  p.text-gray-900.dark:text-gray-100
```

## Components

### Buttons

```slim
/ Primary button
button.bg-blue-500.hover:bg-blue-600.text-white.px-4.py-2.rounded
  | Save

/ Secondary button
button.bg-gray-200.hover:bg-gray-300.text-gray-800.px-4.py-2.rounded
  | Cancel

/ Danger button
button.bg-red-500.hover:bg-red-600.text-white.px-4.py-2.rounded
  | Delete
```

### Forms

```slim
/ Form group
.mb-4
  label.block.text-sm.font-medium.text-gray-700.mb-1 for="email"
    | Email
  input.w-full.border.border-gray-300.rounded.px-3.py-2 type="email" id="email"

/ With error
.mb-4
  label.block.text-sm.font-medium.text-red-700.mb-1
    | Email
  input.w-full.border.border-red-500.rounded.px-3.py-2
  p.text-red-500.text-sm.mt-1 = error_message
```

### Cards

```slim
.bg-white.dark:bg-gray-800.rounded-lg.shadow.p-6
  h3.text-lg.font-semibold.mb-4
    | Card Title
  p.text-gray-600.dark:text-gray-300
    | Card content here
```

### Modals

Use the `modal_controller.js` Stimulus controller:

```slim
div data-controller="modal"
  button data-action="click->modal#open"
    | Open Modal

  / Overlay
  .hidden.fixed.inset-0.bg-black.bg-opacity-50.z-40 data-modal-target="overlay" data-action="click->modal#close"

  / Dialog
  .hidden.fixed.inset-0.z-50.flex.items-center.justify-center data-modal-target="dialog"
    .bg-white.rounded-lg.p-6.max-w-md.w-full.mx-4
      h2.text-xl.font-bold.mb-4
        | Modal Title
      p.mb-4
        | Modal content
      button data-action="click->modal#close"
        | Close
```

## Helpers

### Progress Bar

```slim
= progress_bar(current: 75, max: 100, label: "Progress", show_percentage: true)
= capacity_bar(current: 8, max: 10, label: "Storage")
```

## Accessibility

- Use semantic HTML (`button` for buttons, `a` for links)
- Add `aria-label` to icon-only buttons
- Ensure sufficient color contrast (4.5:1 minimum)
- Support keyboard navigation (focusable elements, ESC to close modals)

## Responsive Design

Use Tailwind breakpoints:

```slim
/ Mobile-first approach
.grid.grid-cols-1.sm:grid-cols-2.lg:grid-cols-4.gap-4
  .card
    | Item 1
  .card
    | Item 2
  .card
    | Item 3
  .card
    | Item 4
```

| Breakpoint | Min Width | Usage |
|------------|-----------|-------|
| `sm:` | 640px | Tablet portrait |
| `md:` | 768px | Tablet landscape |
| `lg:` | 1024px | Desktop |
| `xl:` | 1280px | Large desktop |
