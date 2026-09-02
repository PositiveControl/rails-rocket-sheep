# Three vertical traces through a real Rails app

Evidence for the API rule set ([ADR 0009](../.agents/adr/0009-api-mode-is-a-generation-flag.md)),
and the input to the `write-path` rework.

`write-path` states the layer order end to end. It is the one rule that cannot be
written from principle, because the question it answers — *which layer is allowed to
know what* — is only visible in code that has been under pressure. So three requests
in the audited app were traced end to end: the deepest money write, the only JSON
write behind token auth, and a paginated index.

The plan called for a file-download trace as the third. That path is HTML-shaped and
teaches nothing about a JSON boundary, so the scanner write took its place.

<!-- lint-docs:ignore — every count below describes the audited app, not this repo -->

## Trace 1 — a JSON write behind token auth

`PATCH /api/scanner/batches/:id/receive`

```
BaseController#authenticate_scanner_session!   bearer token, verifier, revocation, role
  BatchesController#set_batch                  find_by, render 404 if nil
  BatchesController#receive                    state guard, 422 if wrong status
    #perform_receive                            transaction { assign; log_processing_step }
      BatchSubmission#log_processing_step        writes the log, then save!
  #batch_summary / #batch_detail / #item_detail  three private serializers
```

This is the best-built JSON endpoint in the app and still shows four things a rule
has to prevent.

**The write persists as a side effect.** `perform_receive` assigns `batch.status` and
then calls `log_processing_step`, whose last line is `save!`. The status reaches the
database because an unrelated method happened to save the record. Change that method
to `update_column` and the status silently stops persisting, while the response keeps
reporting `status: batch.status` from memory — a response that lies with no failing
test in sight.

**The transaction is decorative.** It wraps one `save!`. A transaction around a
single statement communicates a boundary that isn't there, which is worse than none,
because the next person adds a second write outside it and assumes they are covered.

**Three serializers, private, in the controller.** `batch_summary`, `batch_detail`
and `item_detail` — the shape of a batch is defined here and nowhere else, so no
other endpoint can return a batch consistently.

**An N+1 the preloads miss.** `show` preloads `:tickets` and `:capture_images`, and
`item_detail` then reads `item.item_location&.location_notes` — a `has_one` that was
not preloaded. One query per item, in the response builder, where no one looks.

Also: `index` maps an unbounded relation. The collection is never rendered directly,
which is why a scan for unbounded *renders* comes back clean, and the response is
unbounded anyway.

## Trace 2 — the deepest money write

`PATCH /purchases/:id` — checkout, hidden in a REST `update`

```
PurchasesController#update                     validate_update_params, then delegate
  SelectiveCheckoutService                     splits the cart, 3 call sites into ↓
    PurchaseCheckoutService (521 lines)
      #execute_phase_one    transaction { lock items FOR UPDATE, lock balance, write }
      #execute_phase_two    Stripe calls, outside the transaction
  case result / in {...}                        three-way pattern match, then render
```

**The good part, and it should be a rule.** Phase one holds a transaction and takes
row locks; phase two talks to Stripe *outside* it. Nobody holds a database
transaction open across a payment API call. Two other services on this path lock
explicitly before validating a balance. That is a hard-won pattern and the corpus
should state it.

**The write path has three outcomes, not two.** The controller pattern-matches
success, failure, and *prices changed — confirm before proceeding*. A `Result` with
`success?` and `failure?` cannot express the third, and it is not an edge case; it is
a normal outcome of a cart whose items moved. In HTTP that is a distinct status and,
under RFC 9457, a distinct problem `type`. A two-state Result forces it into one of
the other two.

**The controller identifies an error by matching its message.**

```ruby
card_was_declined = errors.to_s.start_with?("Card declined")
```

The type of a failure is recovered by string-matching English prose that a service
built for a human to read. Rewording the message changes control flow. This single
line is the strongest argument in the codebase for a machine-readable error identity,
which is exactly what RFC 9457's `type` field is for.

**The action is ~110 lines, and almost none of it is business logic.** It is response
assembly: two `turbo_stream.replace` calls with eight locals each, a recalculated
price breakdown, a partial choice per branch. Strip the view layer and this action is
about ten lines. That is the real reason controllers in HTML-first Rails apps grow,
and it means API mode's `controllers` rule inherits a much smaller problem than the
HTML one does.

**The controller knows the service's internals.** Its failure branch comments that
"`SelectiveCheckoutService` already reverts card_declined → cart", then compensates
for what that revert destroyed. The boundary leaks in both directions.

## Trace 3 — a paginated index

`GET /items`

```
ItemsController#index
  #load_items_index                     reads params, sets 6 ivars
    ItemFilters#build_items_query        5 keyword args, status + category + search
    SortingConcern#apply_sorting         sanitize column, sanitize direction, 4 strategies
    PaginationConcern#paginate           page/per_page/offset, or Array#slice
  respond_to → html | turbo_stream
```

**This is `app/filters/` in all but name, and it validates the seventh directory.**
The app independently grew a filter-sort-paginate pipeline for its index actions. It
grew as three controller mixins, and the mixin form is why `ItemFilters` is 214 lines
that also compute filter counts and build breadcrumb hashes: a concern can reach
`params` and set `@ivars`, so unrelated responsibilities drift in. As objects with an
explicit relation in and out, those responsibilities separate on their own.

**Sorting is already sanitized.** `sanitize_sort_column` plus a column-existence check
and pattern matching for computed sorts. The allowlist instinct is present; what is
missing is that the allowlist is not readable as data, so nothing can generate an
OpenAPI `parameters` block from it.

**Pagination accepts an Array.** `paginate` branches on `collection.is_a?(Array)` and
falls back to `slice(offset, per_page)`. Any caller passing an Array has already
loaded the whole set into memory, and the pager hides it. This is where the unbounded
read actually lives — not in the render.

**Two relations, deliberately.** `@total_items` unpaginated for filter counts,
`@items` for the page, with a comment explaining which preloads belong on which. The
count query and the page query are separate concerns, and a cursor rule has to say
what happens to the count.

## The service population these traces sit in

The traces were also meant to size the P4 pass. The population:

| | |
|---|---|
| Service files | 356 |
| Total lines | 44,396 |
| Median / mean / p90 / max lines | 86 / 124 / 254 / 1,573 |
| Services defining a `Result` | 63 |
| **Distinct `Result` shapes among them** | **38** |
| Services with no `Result` | 293 |
| Error classes declared inside service files | 62 |
| Error classes in `app/exceptions/` | 1 |
| Transactions opened in services / controllers / models | 55 / 23 / 1 |

Thirty-eight shapes for one concept. The variants are not only in the payload name —
`success?` against `success`, `errors` against `error`, one `ok`, and members ranging
from two to five. Two services on the same checkout path disagree: one is
`(success?, data, errors)` positional, the other adds `price_changes` and
`cart_purchase` with `keyword_init`. A caller cannot be written against "a service
Result" in this app; it has to be written against one service.

The adopted corpus already recorded the cause — no `ApplicationService`, so no shared
`Result` — and this is the size of it. It is also the clearest possible argument for
shipping the base class before the rules that describe it.

Transactions opened in 23 controllers is the other number worth keeping. The write
boundary is supposed to be the service; it is in the controller often enough that
`write-path` has to say so explicitly rather than implying it.

## What this changes

**`write-path`, for API mode.** The chain the traces support, with the view layer
gone and the two things they caught named:

```
Request
  → Controller    authenticate, authorize, validate the contract, delegate, map Result to status
    → Filter      untrusted query string → relation           (reads)
    → Service     owns the transaction; network calls outside it   (writes)
      → Model     validates and persists; a save is never a side effect of a logger
      → Job       enqueued after commit
  → Serializer    the response shape, defined once per resource
```

Two clauses in that diagram are there because a trace put them there: *network calls
outside the transaction*, and *a save is never a side effect*.

**`status-codes` needs three outcomes.** Success, failure, and needs-confirmation.
Whatever `ApplicationService::Result` looks like in API mode, a two-state version
cannot carry the checkout path, and the third state has to map to one status and one
problem `type` rather than being flattened.

**`error-envelope` needs a machine-readable type, and the evidence is a single line.**
A controller matching `"Card declined"` against a prose string is what an envelope
without a `type` field costs.

**`filters` is confirmed by precedent** rather than argued from first principles.

**The P4 sampling frame.** Reading 356 services is 44,396 lines and unnecessary.
Three strata instead: the five services on the traced write path, read fully; one
representative of each of the 38 `Result` shapes, read only for its Result and its
rescue structure; and the 36 files above the p90 line, skimmed for what makes them
big. About eighty files, partially read, against three hundred and fifty-six.

## Method

Entry points located from `config/routes.rb`, then each layer followed by reading the
called method rather than grepping for it, so that indirection through concerns and
service-to-service calls was actually walked. Every claim about persistence was
checked against the method that performs it — the `log_processing_step` finding began
as a suspected missing `save!` and became a finding about implicit persistence only
after reading the model. Counts come from one commit; the ratios are the durable part.
