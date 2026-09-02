# Errors Are Problem Documents

**Applies to:** API mode. A server-rendered app answers a failed write with a `422`
and a re-rendered form, which is the decision in
[`../rules/exception-boundary.md`](../rules/exception-boundary.md) — this one replaces
it at the JSON boundary.

**Status:** Accepted

**Context:**
Every JSON API invents an error envelope, and every one of them invents a slightly
different envelope per controller. The failure is not aesthetic. Once the body has no
machine-readable identity for the failure, a client that needs to tell "card
declined" from "validation failed" has nothing to branch on but prose, and prose gets
reworded. An audited app with no rule here grew five keys for the one concept —
`error`, `errors`, `message`, `success`, `ok`, with `errors` typed two ways — and one
controller recovered a failure's identity with
`errors.to_s.start_with?("Card declined")`.

**Decision:**
[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem details, served as
`application/problem+json`. One `problem` helper on `Api::V1::BaseController` writes
every error body; no action writes one by hand. The `type` member is the contract and
a client branches on it; `detail` is prose for a human and no client reads it. Field
validation goes in an `errors` extension, one object per field, each with its own
code. No `success` or `error` boolean anywhere in a body — the status line already
says that. `401`, `403` and `404` carry a body like everything else.

A standard cited is shorter to write down and more durable than a shape invented
here. The working conventions are in
[`../rules/error-envelope.md`](../rules/error-envelope.md); which status goes with
which failure is [`../rules/status-codes.md`](../rules/status-codes.md).

**Consequences:**
- (+) One shape to document, one shape for a client to parse, and the problem types
  are enumerable — they appear in the generated contract
  ([ADR 0013](0013-the-api-contract-is-generated-from-its-tests.md))
- (+) `Content-Type` distinguishes an error body from a success body without parsing
  it
- (+) Nothing invented, so a client generator and a reader already know the shape
- (-) `type` values are API surface: adding one is a change, renaming one is a
  breaking change, and that has to be remembered at the point of adding an error
- (-) Every library that answers a request has to be pointed through the helper.
  Doorkeeper needed `handle_auth_errors :raise` to stop answering in its own shape,
  and the next such gem will need its own line
- (-) `application/problem+json` surprises a client that hard-codes
  `application/json`, and browsers will not pretty-print it
