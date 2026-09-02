---
id: error-envelope
title: Errors are problem documents — RFC 9457, one shape, a machine-readable type
applies_to: ["app/controllers/**/*.rb", "app/lib/problem.rb"]
triggers: ["error response", "problem+json", "RFC 9457", "error envelope", "422 body", "error json", "errors array", "validation errors", "error message"]
see_also: ["status-codes", "exception-boundary", "serialization", "request-contracts"]
modes: [ api ]
tokens: 840
current_state: matches
---

# Errors are problem documents

Every error response in this app is a single shape: [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457)
problem details, served as `application/problem+json`. One helper writes it, and no
action writes an error body by hand.

```ruby
# app/controllers/api/v1/base_controller.rb
def problem(type:, title:, status:, detail: nil, **extensions)
  render content_type: "application/problem+json",
         status: status,
         json: {
           type:   "/problems/#{type}",
           title:  title,
           status: Rack::Utils.status_code(status),
           detail: detail,
           **extensions
         }.compact
end
```

```ruby
problem type: "card-declined", title: "Card declined", status: :payment_required,
        detail: gateway_message
```

**`type` is the contract; `detail` is for a human.** A client branches on `type` and
never on `detail`, because `detail` is prose someone will reword. Types are
kebab-case, stable for the life of a major version, and listed in the generated
contract — adding one is an API change, renaming one is a breaking change. RFC 9457
permits a relative URI reference, which is why there is no hostname to configure
here.

**Field validation goes in an `errors` extension**, one entry per field, each with its
own machine-readable code:

```ruby
problem type: "validation-failed", title: "Validation failed",
        status: :unprocessable_content,
        errors: record.errors.map { |e|
          { field: e.attribute, code: e.type, detail: e.full_message }
        }
```

That is the only place a list appears. `errors` is always an array of objects, never
a bare string and never a hash keyed by field — a client that has to type-check the
value before reading it has no contract.

**Never a success or error boolean in the body.** The status line already carries
whether the request succeeded. A `success: false` beside a `422` is a second source
of truth, free to disagree with the first, and it makes every client decide which one
wins.

**A 404 has a body.** So does a 401 and a 403. An empty error response tells a client
nothing about whether to retry, re-authenticate, or give up.

**The cost is measured.** The audited app grew five keys for this one concept —
`error`, `errors`, `message`, `success`, `ok`, with `errors` typed two ways — and one
controller recovers an error's identity by matching English:

```ruby
card_was_declined = errors.to_s.start_with?("Card declined")
```

Control flow through a prose string is what an envelope with no `type` costs.

Which status goes with which failure: [status-codes](status-codes.md). Turning a
raised exception into one of these: [exception-boundary](exception-boundary.md).
