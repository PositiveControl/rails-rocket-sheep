---
id: status-codes
title: Status codes — the ones you need, and the outcome that is neither success nor failure
applies_to: ["app/controllers/**/*.rb", "test/integration/**/*.rb"]
triggers: ["status code", "201", "202", "204", "409", "422", "400 vs 422", "401 vs 403", "which status", "head :no_content", "needs confirmation"]
see_also: ["error-envelope", "async-202", "request-contracts", "service-objects"]
modes: [ api ]
tokens: 920
current_state: matches
---

# Status codes

The controller decides the status. A service returns a `Result`; mapping that to a
number is the controller's job and belongs nowhere else, because the same service is
called from a job and a console where there is no status to set.

| Status | For |
|---|---|
| `200` | A read, or a write whose response body is the updated resource |
| `201` | A create. Set `Location` to the new resource |
| `202` | Accepted, work continues elsewhere — see [async-202](async-202.md) |
| `204` | A delete, or a write with genuinely nothing to say |
| `400` | The request is malformed — unparseable body, wrong content type |
| `401` | No credentials, or credentials that failed |
| `403` | Valid credentials, insufficient scope or permission |
| `404` | No such resource, *or* one this caller may not know exists |
| `409` | The request conflicts with the resource's current state |
| `422` | Well-formed and semantically wrong — validation failure |
| `429` | Rate limited. Always with `Retry-After` |

**`400` and `422` are not interchangeable.** `400` means the request could not be
understood; `422` means it was understood and rejected. A client retries neither, but
it reports them differently, and a `400` that should have been a `422` sends a
developer looking at their JSON serializer instead of their form.

**`401` and `403` are not either.** `401` invites the client to authenticate again;
`403` tells it not to bother. Answering `403` to an expired token makes clients log
users out that a refresh would have saved.

**`404` is also the answer for "not yours".** A record the caller may not know exists
is a `404`, not a `403` — a `403` confirms the id is real, which is an enumeration
oracle. Scope the lookup and let it raise; see [policy-objects](policy-objects.md).

## The outcome that is neither

A write can have a third result: correct, permitted, and not safe to complete without
the client confirming something that changed underneath it. In the audited app that
is a cart whose prices moved between loading and checkout — a normal outcome, not an
edge case.

That is `409`, with its own problem `type` and enough of the conflict in the body for
the client to show it:

```ruby
if result.needs_confirmation?
  problem type: "prices-changed", title: "Prices changed", status: :conflict,
          detail: "Confirm the new total to continue",
          **result.confirm
else
  ...
end
```

**A two-state Result cannot carry this.** `success?` and `failure?` would force the
third outcome into one of the other two, and flattening it into `422` tells the client
to fix its input when there is nothing wrong with its input. `ApplicationService`
carries it as a third state: `needs_confirmation(**details)` returns a Result that is
neither a success nor a failure, and `confirm` holds what the client has to see —
[service-objects](service-objects.md).

**Every status in this table gets one request test.** They are the cheapest tests in
the suite and the ones a client integration breaks on — [api-testing](api-testing.md).
