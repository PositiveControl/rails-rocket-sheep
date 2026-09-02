---
id: client-contract
title: What the client repo may rely on, and what it must not
applies_to: ["openapi.yaml", "app/serializers/**/*.rb", "app/controllers/api/**/*.rb"]
triggers: ["client", "frontend", "JS client", "SPA", "what can the client assume", "breaking the client", "consumer"]
see_also: ["openapi-contract", "api-versioning", "error-envelope", "cursor-pagination", "deprecation-policy"]
tokens: 740
current_state: matches
---

# The client contract

The JS client is a separate repository this template does not own, so this rule is the
one place the two sides are written down together. It exists to be read from both.

**The client consumes `openapi.yaml` and nothing else.** Not a Slack message, not a
controller someone read. If a behaviour the client depends on is not in the generated
document, the dependency is undeclared and the server is free to change it —
[openapi-contract](openapi-contract.md).

## What the server promises

- **Additive change only within a version.** Fields appear; they do not disappear,
  change type, or change meaning — [api-versioning](api-versioning.md).
- **A stable `type` on every error.** Kebab-case, unchanged for the life of the
  version, and safe to branch on — [error-envelope](error-envelope.md).
- **`snake_case` keys, ISO 8601 times, money in minor units with a currency.**
- **A sunset date before anything is removed**, in the `Sunset` header and the document
  — [deprecation-policy](deprecation-policy.md).

## What the client must not do

- **Parse `detail`, or any prose.** It is written for a human and will be reworded.
  Branch on `type`.
- **Decode a cursor.** It is opaque by design, and its contents change when a sort
  does — [cursor-pagination](cursor-pagination.md).
- **Assume a field's absence means anything.** A missing optional field means it was
  not requested or does not apply, never that it is empty
  ([sparse-fieldsets-includes](sparse-fieldsets-includes.md)).
- **Construct a URL by string-building where the response gave one.** `Location` and
  `next_cursor` are there to be followed.

## What the client must handle

- **`429` with `Retry-After`.** Back off for the stated interval; do not retry
  immediately, and do not retry forever.
- **`202` and a `Location`.** Poll the status resource at the documented interval
  ([async-202](async-202.md)).
- **`401` versus `403`.** `401` means refresh or re-authenticate. `403` means stop —
  logging the user out on a `403` is the wrong response to a scope problem.
- **An unknown `type`.** Fall back to `title` and the status; a new problem type is an
  additive change and must not break the client that meets it first.

**Neither side gets to be right by having read the code.** A disagreement is settled by
the document, and if the document is silent that is the bug to fix first.
