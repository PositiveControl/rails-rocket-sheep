---
id: stimulus
title: Stimulus — targets, values, classes; never reach outside the element
applies_to: ["app/javascript/controllers/**/*.js", "app/components/**/*.js", "app/views/**/*.slim"]
triggers: ["Stimulus", "data-controller", "static targets", "static values", "static classes", "querySelector", "connect()", "disconnect()", "data-action", "toggle_controller", "modal_controller", "localStorage"]
see_also: ["tailwind-build", "turbo-frames", "components"]
modes: [ web ]
tokens: 620
current_state: matches
---

# Stimulus

Controllers named `thing_controller.js`. Two generic ones ship with the app:
`toggle_controller.js` and `modal_controller.js`. Reach for those before writing a
new one.

## The contract

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

## Rules

- **Targets, values, classes — never `document.querySelector`.** A controller that
  reaches outside its own element breaks the moment Turbo replaces the DOM.
- **No Tailwind class strings in JavaScript.** Pass them as `static classes` so the
  compiler can see them in the template — see [tailwind-build](tailwind-build.md).
- **The server owns truth, the controller owns feel.** Anything that must persist
  goes through a form or a `fetch` to a real controller action, not into
  `localStorage`.
- **Idempotent `connect()`.** It runs on every Turbo navigation, cache preview, and
  morph. Clean up in `disconnect()` — timers, listeners, observers. See
  [turbo-frames](turbo-frames.md) on morphing.
- **Component-scoped controllers** live in the component's sidecar directory when
  they exist only for that component.
