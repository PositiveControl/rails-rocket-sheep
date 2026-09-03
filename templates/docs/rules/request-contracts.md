---
id: request-contracts
title: Request contracts — validate the body before it reaches a model
applies_to: ["app/contracts/**/*.rb", "app/controllers/api/**/*.rb"]
triggers: ["strong params", "permit", "request validation", "params object", "contract", "invalid body", "422", "unknown field", "type coercion"]
see_also: ["error-envelope", "status-codes", "filtering-sorting", "pattern-budget", "service-objects"]
modes: [ api ]
tokens: 1000
current_state: matches
---

# Request contracts

An untrusted request body is validated by a contract in `app/contracts/` before any
model sees it. Strong params filters keys; it does not validate them, and on a JSON
API those are different jobs.

```ruby
class Items::CreateContract < ApplicationContract
  attribute :title,       :string
  attribute :price_cents, :integer
  attribute :category_id, :string

  validates :title,       presence: true, length: { maximum: 120 }
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :category_id, presence: true
end
```

```ruby
def create
  contract = Items::CreateContract.new(item_params)
  return problem(type: "validation-failed", title: "Validation failed",
                 status: :unprocessable_content, errors: contract.error_details) if contract.invalid?

  result = CreateItemService.new(current_user, contract).call
  ...
end
```

**A contract returns a validated value object, never a relation.** That is what
separates it from a [filter](filtering-sorting.md), which validates the query string
and returns a relation. Same job — allowlist, coerce, reject — on the two halves of
one request, and the return type is the reason they are two directories
([pattern-budget](pattern-budget.md)).

**Declare the type, then validate the range.** This is the trap the pattern exists
for: `ActiveModel` casts `"abc"` to `0` for an integer attribute, silently. A declared
type without a `numericality` check turns a client's typo into a free item. Every
numeric attribute gets a bound; every string that matters gets a length. The range
alone is not the catch: `ApplicationContract` makes `numericality` read the value the
client sent rather than the cast one, so `"abc"` fails as *not a number* even where
`0` would be in range. On an update contract add `allow_nil: true`, or an omitted
field fails the same check.

**Unknown keys are ignored, not rejected.** [Versioning](api-versioning.md) promises a
`v1` client keeps working, and the mirror of that promise is that a client sending a
field from a newer build is not an error. Rejecting unknown keys breaks clients for
being ahead.

**A malformed body is `400`; a well-formed invalid one is `422`.** Unparseable JSON or
the wrong content type never reaches the contract — that is the boundary's job
([exception-boundary](exception-boundary.md)). The contract only ever produces `422`.

**Model validations stay where they are.** A contract is not a replacement for them;
it is what stops a type error reaching them. The model remains the last line, because
a service and a console can write without passing a contract at all.

**One contract per write, named for it.** `Items::CreateContract`,
`Items::UpdateContract`. An update whose rules genuinely match create can subclass it,
but the two usually differ — required on create, optional on update — and one contract
serving both grows conditionals nobody can read.

**Omitted is not null.** `to_h` returns only the keys the client sent, so a
`PATCH { "status": "done" }` through an update contract yields `{ status: "done" }`
and a service that splats it leaves the title alone. A field the client sent as
`null` is still returned, as `nil`. "Optional on update" is `if: -> { provided?(:title) }`
on the validation, not a missing `presence` check.
