# API scaffolding was out of scope, and is not any more

**Reversed.** See [ADR 0009](../adr/0009-api-mode-is-a-generation-flag.md). This file
is kept because the reasoning is what the reversal had to satisfy, and because a
ruling that vanishes when it is overturned teaches nobody anything.

## What was declined, and why

No JSON serializers, no versioning scheme, no docs generation, no API key model.

The rule corpus was HTML-shaped on purpose. Form failures render 422 so Turbo does
not discard the response (`docs/rules/turbo-status.md`); the exception boundary turns
a missing record into a redirect (`docs/rules/exception-boundary.md`); every index
paginates through Pagy (`docs/rules/pagination.md`). An API layer needs its own answer
to each of those, and they are different answers: a JSON error envelope, a 404 with a
body, cursor pagination.

Shipping scaffolding without those conventions would put a second architecture in the
app with no rules describing it, which is the failure this product exists to prevent.
Writing the conventions is the real work, and it is a distinct product decision rather
than a file to add.

## What changed our mind

The condition this file set: *enough demand to justify a rule set for JSON endpoints,
not scaffolding. If that lands, the scaffolding becomes cheap.*

It landed, in that order. Seventeen rules for the JSON boundary, written before any
base class existed — an error envelope (RFC 9457), a 404 with a body, cursor
pagination, and the fourteen others the audit and the traces argued for. The
scaffolding then took one commit, exactly as predicted.

The evidence is in [`docs/json-boundary-audit.md`](../../docs/json-boundary-audit.md),
which measured what a Rails app's JSON surface looks like with no rules governing it:
five different keys for the error concept, `errors` typed two ways, and none of 289
responses passing through a serializer. That is the second architecture this ruling
was written to avoid, observed in the wild.

## What it cost to be right about the order

Nine defects surfaced the first time an app was generated
([`docs/first-generation-findings.md`](../../docs/first-generation-findings.md)), and
one of them is this file's argument in miniature: Doorkeeper renders its own 401 and
403 in its own shape, which is a second error format in an app whose premise is having
one. It was caught because the contract generator recorded `content: text/html`, and
it was fixable because a rule already said what the shape should be.

Had the scaffolding shipped first, that response would have been the convention.
