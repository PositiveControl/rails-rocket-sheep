---
id: openapi-contract
title: The contract is generated from the request tests, and CI fails on drift
applies_to: ["test/integration/**/*.rb", "openapi.yaml", ".github/workflows/**"]
triggers: ["OpenAPI", "swagger", "API docs", "contract", "spec drift", "schema", "client generation", "documentation"]
see_also: ["api-testing", "serialization", "filtering-sorting", "client-contract", "api-versioning"]
modes: [ api ]
tokens: 730
current_state: matches
---

# The contract is generated

`openapi.yaml` is committed, and it is a build output. It is produced by running the
request tests, and CI fails when the committed copy and a freshly generated one differ.

```bash
bin/rails api:contract        # regenerate openapi.yaml from the request tests
bin/rails api:contract:check  # exit 1 on drift, which is what CI runs
```

**An untested endpoint is an undocumented endpoint.** That is the property this choice
buys, and it is the reason the tests are the source rather than the routes or the
controllers: a route can exist with no test and no documented behaviour, and this makes
that state visible instead of comfortable.

**A hand-written spec drifts the first week nobody is watching.** So does one generated
from a running server, because it only ever describes what someone happened to
exercise. Generated from tests plus a CI gate is the version that cannot silently rot.

**The generator reads declarations, which is why the other rules make them
declarations.** Serializer field lists ([serialization](serialization.md)), filter and
sort allowlists ([filtering-sorting](filtering-sorting.md)), `optional` and
`includable` ([sparse-fieldsets-includes](sparse-fieldsets-includes.md)), and the
problem types raised in tests ([error-envelope](error-envelope.md)). A rule written as
control flow generates nothing, and that is the practical reason those rules insist on
a table over an `if`.

**Every problem `type` appears in it.** The error shapes are as much the contract as
the success shapes, and they are the half clients get wrong.

**Regenerating is part of the change, not a follow-up.** A PR that adds an endpoint and
leaves `openapi.yaml` stale fails CI, in the same way a stale `tokens:` figure fails
`bin/lint-docs`. Same mechanism, same reason: a document that disagrees with the tree
is worse than no document, because nothing tells the reader.

**One document per version.** `v1` and `v2` are separate files, since a client
generated against a merged document has no way to tell which endpoints it may call
([api-versioning](api-versioning.md)).

The client repo consumes this file and nothing else — [client-contract](client-contract.md).

Rationale and consequences: [ADR 0013](../adr/0013-the-api-contract-is-generated-from-its-tests.md).
