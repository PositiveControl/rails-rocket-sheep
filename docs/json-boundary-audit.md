# What a Rails app's JSON boundary looks like with no rules governing it

Evidence for the API rule set ([ADR 0009](../.agents/adr/0009-api-mode-is-a-generation-flag.md)).
The out-of-scope ruling this reverses predicted that shipping JSON scaffolding
without conventions "would put a second architecture in the app with no rules
describing it". uCollect is that prediction, already run: an HTML-first Rails 8
marketplace that grew a JSON surface with no rule in its corpus describing one.

Audited by scanning every `render json:` site in its controllers and classifying the
payload, the status, and the mechanism. What follows is not a criticism of that app —
it is the best available measurement of which conventions a corpus actually has to
supply, and which ones a competent team arrives at on its own.

## Scale

<!-- lint-docs:ignore — every count in this section describes the audited app, not this repo -->

| | |
|---|---|
| `render json:` sites | 289 |
| Controllers holding them | 41 |
| `format.json` branches, in 9 more | 39 |
| API namespaces in a 952-line routes file | 1, holding 8 routes |
| Version markers anywhere in routing | 0 |
| Responses passing through a serializer class | 0 |

## What the team got right without being told

Worth stating first, because three of these are conventions the corpus can codify
rather than invent, and one of them is a design the API rules should copy outright.

**Status codes are already close to correct.** Of 217 error-shaped bodies, 211 carry
a 4xx or 5xx: 136 `422`, 53 `404`, 7 `403`, 5 `500`, 1 `401`. Only ten error bodies
answer with a 2xx. The `status-codes` rule is therefore mostly a codification of
practice plus a named exception, not a re-education.

**Key casing never wavered.** Zero camelCase keys across 289 sites. Nobody had to be
told; the rule can be one line.

**No relation is rendered directly.** `render json: <relation>` does not occur once;
collections are always mapped to hashes first. That is worth knowing, but it is not
the good news it first looks like — see the correction below.

**The one real API is well built.** `Api::Scanner::BaseController` inherits
`ActionController::API` and, unprompted by any rule, arrives at: a bearer token read
from `Authorization`, tokens signed with `message_verifier`, server-side revocation
by token digest, a second check invalidating every token issued before a per-user
timestamp, a role gate, and two named error helpers. That is a token API with
revocation, which is the requirement Doorkeeper is being adopted to satisfy — and
this app hand-built the same thing because the requirement is real. The API corpus
should treat this controller as the shape to generalise, not as legacy.

## What no rule prevented

**Five ways to say what happened.** Across the JSON hash bodies: `error:` 159 times,
`success:` 29, `errors:` 18, `ok:` 16, `message:` 6. A client consuming this surface
branches on five keys to answer one question.

**Two value types behind one key.** `error:` carries a string literal at 123 sites
and an expression at 67. `errors:` is an array literal at 10 sites, a bare
expression at 5, and `full_messages` at 4 — so `errors` is sometimes a list of
strings and sometimes one string. No client can parse this without a type check per
endpoint.

**A boolean that restates the status line.** 35 bodies carry `success:` or `ok:`, and
23 of those sit alongside a 4xx or 5xx status. Two sources of truth for one fact,
free to disagree, and the client has to decide which one wins.

**Serialization lives at the call site.** Not one of the 289 responses goes through a
serializer class; the two classes that exist are referenced only from a Slim
template. Instead there are eleven private `serialize_*` and `*_payload` methods in
controllers — and `serialize_slot` is defined three times, in three different
controllers, for the same record shape. That is serialization drift with nothing to
diff it against.

**Rescue per action instead of a boundary.** One action carries six `rescue` clauses,
each rendering its own error JSON, several adding a `next_slot:` key the other error
paths omit. The adopted corpus independently recorded the cause — no `rescue_from` in
`ApplicationController` — and this is what it costs at the JSON boundary: the error
shape is re-decided per rescue.

**The good error helpers exist in exactly one file.** `render_unauthorized` and
`render_forbidden` are defined in the scanner base controller and nowhere else. The
other forty controllers hand-write the same two shapes, over two hundred times.

**Nothing is versioned.** No `v1`, no `:version`, and the one API namespace is
unversioned, so its scanner client is pinned to whatever shipped last.

**Unbounded collections, one layer further down than a scan for them looks.** This
audit first read the absence of `render json: <relation>` as the absence of unbounded
responses. Tracing the endpoints ([layer-boundary-traces](layer-boundary-traces.md))
showed otherwise: the scanner index maps an unbounded relation, and the pagination
helper accepts an Array and slices it, so any caller passing one has already loaded
the whole set. The failure mode is present and displaced — a rule that only forbids
rendering a relation would miss all of it.

## What each new rule now has behind it

A rule earns its place partly on the cost of its absence. This audit supplies that
cost for six of the seventeen, and honestly reports which ones it says nothing about.

| Rule | Evidence from the audit |
|---|---|
| `error-envelope` | Five keys, two value types, 217 error bodies. The strongest-motivated rule in the set, and the reason RFC 9457 is worth citing rather than inventing a shape |
| `serialization` | Zero of 289 responses through a serializer; one record shape serialized by three copies of the same method, and three more defined privately inside one controller ([traces](layer-boundary-traces.md)) |
| `api-auth` | One good precedent to generalise, which independently reproduced bearer tokens plus server-side revocation |
| `status-codes` | Mostly codifies existing practice; the ten 2xx error bodies are the exception it needs to name |
| `api-versioning` | No precedent at all. Pure design, and the client coupling is already real |
| `cursor-pagination` | Near-absent: 8 of 289 sites mention any paging concept |

Says nothing about: `request-contracts`, `idempotency`, `cors`, `async-202`,
`bulk-endpoints`, `deprecation-policy`, `sparse-fieldsets-includes`,
`filtering-sorting`, `openapi-contract`, `api-testing`, `client-contract`. Those are
designed from standards, and the P6 pass owns them.

## Drafting notes for `rejected-patterns`

Four entries follow from the above, each with a count behind it rather than a
preference:

- A boolean success flag in the body, when the status line already carries it.
- More than one key for the error concept — `error`, `errors` and `message` in one
  app, with `errors` typed two ways.
- A response hash built in the action. It reads as economy at the first call site
  and as drift by the third.
- An error shape decided inside a `rescue`. Six rescues in one action produced four
  shapes.

## Method

Every `render json:` site in the audited app's `app/controllers/**` was extracted
with its continuation lines, then classified by payload shape, by the `status:`
render option where one was passed, and by mechanism. `status:` was matched only in
the render-option position, since several payloads carry a key of that name.
Serializer, `to_json` and `as_json` usage was counted across `app/`. Counts are from
one commit and will drift; the ratios are the durable part.
