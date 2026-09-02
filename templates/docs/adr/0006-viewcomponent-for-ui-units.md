# ViewComponent for UI Units

**Applies to:** server-rendered mode. An API-only app renders no UI, so this
decision is inert there — it keeps its number rather than being renumbered away.

**Status:** Accepted

**Context:**
Partials carry no interface, can't be unit tested in isolation, and silently read
whatever instance variables the rendering context happens to hold. Markup with
variants and conditionals ends up as a stack of `- if` lines nobody can test.

**Decision:**
Use ViewComponent for UI units that carry logic or variants or are reused. Components
live in `app/components`, inherit `ApplicationComponent`, and ship with a unit test.
Sidecar directories are on, so a component's class, Slim template, and any
component-scoped Stimulus controller sit together. Partials remain the right tool for
logic-free markup reused within one resource, and must declare strict locals.

**Consequences:**
- (+) View code is unit tested without a request, routing, or fixtures
- (+) Explicit constructor interface — no ambient instance variables
- (+) Variants live in one frozen hash instead of scattered conditionals
- (-) One more dependency, and a second place view code can live
- (-) Over-application produces a component per div; the partial/component line is in docs/rules/view-code-placement.md
