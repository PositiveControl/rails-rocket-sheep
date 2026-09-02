# OAuth 2 via Doorkeeper

**Applies to:** API mode. Devise remains the decision for a human-facing surface
where one exists; this covers the token-authenticated API.

**Status:** Accepted

**Context:**
An API-only app has no session to read `current_user` from, so token
authentication is not optional. The cheap answer is a `has_secure_token` column and a
`before_action`; the fashionable one is a self-signed JWT verified without a database
read.

The requirements that decide it do not arrive on day one. An audited app that started
with hand-built tokens had, by the time it was audited, written signed verification,
digest-keyed lookup, revocation and per-user invalidation timestamps — Doorkeeper's
feature list, arrived at one incident at a time.

**Decision:**
Doorkeeper. OAuth 2, bearer tokens, `doorkeeper_authorize!` with coarse scopes
(`read`, `write`, and one per resource family where a client genuinely needs less
than all of it). `current_user` comes from the token's resource owner on
`Api::V1::BaseController`. Scopes answer "may this client"; record-level questions
still go to `app/policies/` ([ADR 0007](0007-pattern-budget.md)) — a `write` token is
not permission to write someone else's row.

`handle_auth_errors :raise` is set, so Doorkeeper's failures go through this app's
exception boundary and come back as problem documents
([ADR 0009](0009-errors-are-problem-documents.md)) instead of Doorkeeper's own
shape. Conventions are in [`../rules/api-auth.md`](../rules/api-auth.md).

**Consequences:**
- (+) Revocation is server-side and immediate: a token can be killed from support
  without a deploy, which is the property a self-signed JWT cannot have
- (+) Scopes, refresh tokens and third-party clients exist before they are needed,
  so the requirement that arrives after launch is configuration rather than a rewrite
  of every client
- (+) A standard flow, so client libraries already speak it
- (-) The heaviest dependency this template takes. A migration set, an initializer of
  real length, and grant flows to understand before the first endpoint
- (-) More machinery than a first-party JS client strictly needs on day one, and it
  looks like overkill until the second client appears
- (-) Every token check is a database read. That is the deliberate trade for
  revocation, and anything that caches it away — a long TTL, a stateless verify path
  added for speed — takes back the reason Doorkeeper was chosen
- (-) Doorkeeper's own defaults assume a browser-facing authorization UI, so the
  parts of it this app does not use still have to be configured off
