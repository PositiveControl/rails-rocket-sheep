# API mode is a generation flag, and it forks the rule corpus

## Context

[`out-of-scope/api-scaffolding.md`](../out-of-scope/api-scaffolding.md) declined
JSON scaffolding, and named the reason: the rule corpus is HTML-shaped on purpose.
Form failures render 422 so Turbo does not discard the response; the exception
boundary turns a missing record into a redirect; every index paginates through
Pagy. An API needs its own answer to each, and they are different answers. The
ruling set its own reversal condition — "enough demand to justify a *rule set* for
JSON endpoints, not scaffolding" — and this is that reversal.

The demand is a specific app: API-only Rails, separate JS client. Not an SSR app
that also serves JSON, which is the case the ruling already had an answer for.

`rails new` already asks the question. `--api` picks the base classes, skips the
view and asset tooling, and thins the middleware stack before `template.rb` gets
control. As with the database family ([ADR
0007](0007-database-family-is-chosen-at-generation.md)), there is no reason to ask
twice.

What makes this a decision rather than a file to add is the corpus. Twelve of the
thirty-eight rules describe a view layer that API mode does not have, and
seventeen conventions the API needs have no rule at all.

What it costs to point this corpus at a real app is not a guess: one app has adopted
it, and the differences were measured in
[docs/adoption-drift-findings.md](../../docs/adoption-drift-findings.md). The two
findings that bear on the decisions below are that a rule naming a mechanism gets
rewritten wherever the app's mechanism differs, while a rule stating a property of
Rails survives verbatim; and that the index's path routing fans out badly once a
single path has many rules pointing at it, which `app/controllers/**` will in API
mode.

What the JSON boundary looks like in an app with no rules governing one was measured
in the same app: [docs/json-boundary-audit.md](../../docs/json-boundary-audit.md).
It is the cost evidence behind the error-envelope and serialization rulings below,
and it supplies the precedent the auth ruling generalises.

## Decision

`template.rb` reads `options[:api]` into an `API` boolean and branches on it, the
same shape as `POSTGRESQL`. One template, two modes, one
`bin/rocket-sheep-update` path.

The corpus splits by disposition, not by copy:

| Disposition | Count | Effect in API mode |
|---|---|---|
| Transfer unchanged | 13 | copied verbatim; `query-objects`, `scopes`, `jobs`, `deletes`, `safe-migrations`, `audit-trail` and the rest are layer-agnostic |
| Transfer with edits | 7 | `controllers`, `exception-boundary`, `pagination`, `policy-objects`, `rate-limiting`, `service-objects`, `testing` state both flavours in one file, as `database-conventions` already does |
| Reworked | 3 | `form-objects` → `request-contracts`; `pattern-budget`; `write-path` |
| Not copied | 12 | `components`, `empty-states`, `forms-ui`, `partials`, `slim-gotchas`, `stimulus`, `tailwind`, `tailwind-build`, `turbo-frames`, `turbo-status`, `turbo-streams`, `view-code-placement` |
| New | ~17 | the JSON boundary — the list is in the plan doc, and each lands with its rule |

Rules state both flavours rather than becoming `.tt`, because a rule that becomes
a template loses its three-way merge ([ADR
0005](0005-updates-are-a-three-way-merge-from-the-stamp.md)). Mode-specific rules
are separate files and `INDEX.md` is generated per mode; `adopt.rb` copies by glob,
so a rule added later is adoptable without a manifest edit.

What the flag concretely means — each of these is a generated-app decision, and each
now has its file in `templates/docs/adr/` (0009-0013, with the budget amending 0007):

| Concern | Ruling |
|---|---|
| Errors | RFC 9457 problem documents, `application/problem+json`. A standard cited is shorter and more durable than a shape invented |
| Serialization | Plain Ruby objects under `app/serializers/`, an `ApplicationSerializer` base, no gem. Matches the PORO taste of `ApplicationService` and the `Data` registries |
| Authentication | OAuth 2 via Doorkeeper. Scoped, revocable, third-party-capable; Devise stays for the human-facing surface where one exists |
| Pagination | Cursor first, offset as the named exception for page-numbered clients |
| Contract | One OpenAPI document, generated from request tests, with a CI gate on drift between the committed and generated copy |
| Pattern budget | Seven directories: `services`, `queries`, `policies`, `serializers`, `contracts`, `filters`, `lib` |

The budget moves from six to seven. `components` and `forms` lose their basis;
`serializers`, `contracts` and `filters` each clear the three bars in
[`pattern-budget`](../../templates/docs/rules/pattern-budget.md) on an API. Seven
is a worse slogan than six and the honest number.

`app/filters/` holds the translation of untrusted query string into scope calls on
a relation: the filterable-param allowlist, type coercion, the param-to-scope
mapping, the sortable-key allowlist and the deterministic tiebreak a cursor needs
to not skip and repeat rows. The allowlist is also the source of the generated
OpenAPI `parameters` block, so it has to be readable as data rather than expressed
as control flow in an action.

It is not a query object. A query object is a named read with a fixed shape that
takes domain arguments you trust; a filter has a client-driven shape and takes
input you do not. They compose — `ItemFilter.new(AvailableItemsQuery.call(user:),
params).apply` — and the untrusted half is the one worth seeing in a directory
name.

Folding it into `contracts` was the alternative, and the reason the budget could
have stayed at six: a write contract and a read filter do the same three things —
allowlist, coerce, reject — to the two halves of one request. Declined because
they return different kinds of thing. A write contract yields a validated value
object; a filter yields a relation. Two return types under one name is how a
directory becomes a junk drawer, and `filters` is the word an agent arrives with.

The JS client is out of scope as code and in scope as a contract: the OpenAPI
document, CORS, the token handshake and the error shape are rules here; no
JavaScript ships.

## Consequences

Accepted:

- **Two generated-app ADRs do not apply in API mode.** `docs/adr/0005-slim-templates`
  and `0006-viewcomponent-for-ui-units` describe a layer that is not there. They
  keep their numbers and gain a mode line, rather than being renumbered or
  dropped — the number is the identity ([ADR 0008](0008-decisions-are-one-file-each.md)).
- **The routers are the one pair of files whose name changes on the way in.** Each
  mode has its own committed pair, `INDEX.md`/`SYMPTOMS.md` and
  `INDEX.api.md`/`SYMPTOMS.api.md`, and the mode's pair installs under the shared
  names because every other file links to those. Two static readers of `adopt.rb` had
  to learn it: `bin/lint-docs` checks each index against only its own mode's rules,
  and `bin/rocket-sheep-update` maps a router to the app's index only when it belongs
  to the app's mode. Without the second, a change to the web index would have merged
  into an API app's `INDEX.md` — the same filename holding different routing.
- **The mode is read, not asked.** `rails new --api` writes `config.api_only`, and an
  app adopting the layer already knows what it is, so both entry points detect it from
  `config/application.rb` rather than carrying a flag. A generated app that later
  changes its mind has to re-run adoption; nothing detects a mode that changed.
- **`modes` is the manifest.** A rule added later ships to the right apps without an
  edit to `adopt.rb`, which is what keeps the glob honest. The cost is that a rule with
  no `modes` line ships nowhere, so the key is required rather than defaulted.
- **Doorkeeper is the heaviest dependency this template has taken.** OAuth 2 for
  a first-party client is more machinery than opaque tokens, and the migration set
  and grant-flow configuration are real. It is chosen for what it does not have to
  be replaced by later: scopes, revocation and third-party clients are the
  requirements that arrive after launch, and a token model rewritten under load is
  worse than Doorkeeper adopted early.
- **`filters` and `contracts` are adjacent and will be confused.** Both allowlist
  untrusted input at the same boundary, and the split between them is by return
  type rather than by responsibility. Each rule states the test in one line —
  request body to a validated object, query string to a relation — and
  `pattern-budget`'s table carries it too, or the seventh directory becomes the
  sixth by drift.
- **Cursor pagination interacts with UUID primary keys.** On PostgreSQL, keys are
  `uuid` and unordered, so a cursor is a `(created_at, id)` composite, not an id.
  `implicit_order_column = :created_at` is already set for this reason; the
  pagination rule has to say the rest.
- **The corpus is written twice at every boundary rule.** Seven files carry both
  flavours, and an agent reading the wrong half writes a redirect into a JSON
  endpoint. Mitigation is the same as the database split: `CLAUDE.md` states the
  mode, the rule routes off it, and the wrong half fails loudly in a request test.
- **`--api` is verified from an emptier baseline.** Only PostgreSQL SSR has ever
  been generated and run in this repo's history. API mode starts with the same
  debt and no field use, and step 7 of the plan — one real endpoint plus a client
  hitting the generated contract — is the only thing that will find it.

Gained: the reversal condition the out-of-scope ruling asked for, satisfied in the
order it asked for. The rule set is the work; the scaffolding is cheap once it
exists.

## Revisit when

A third mode is asked for, or the first rule needs advice in one mode that
contradicts the other. Either is the point at which mode-specific rules should
move into `docs/rules/web/` and `docs/rules/api/` over a shared core, and the
`API` boolean should become a proper predicate — reviewed as a set, rather than
each branch grown in place.
