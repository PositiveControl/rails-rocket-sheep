# API scaffolding is out of scope

No JSON serializers, no versioning scheme, no docs generation, no API key model.

## Why this is out of scope

The rule corpus is HTML-shaped on purpose. Form failures render 422 so Turbo does
not discard the response (`docs/rules/turbo-status.md`); the exception boundary
turns a missing record into a redirect (`docs/rules/exception-boundary.md`); every
index paginates through Pagy (`docs/rules/pagination.md`). An API layer needs its
own answer to each of those, and they are different answers: a JSON error envelope,
a 404 with a body, cursor pagination.

Shipping scaffolding without those conventions would put a second architecture in
the app with no rules describing it, which is the failure this product exists to
prevent. Writing the conventions is the real work, and it is a distinct product
decision rather than a file to add.

## What to do instead

An app that also serves JSON: keep the API in its own namespace with its own base
controller, and write the conventions for it as rules in `docs/rules/` as you go.
`docs/rules/query-objects.md` and `docs/rules/policy-objects.md` transfer directly;
the Turbo and forms rules do not apply.

## What would change our mind

Enough demand to justify a *rule set* for JSON endpoints, not scaffolding. If that
lands, the scaffolding becomes cheap and the decision reverses on its own.
