---
id: async-202
title: Long work answers 202 with somewhere to look
applies_to: ["app/controllers/api/**/*.rb", "app/jobs/**/*.rb"]
triggers: ["202", "accepted", "long running", "timeout", "background", "polling", "job status", "async endpoint"]
see_also: ["status-codes", "jobs", "idempotency", "serialization"]
modes: [ api ]
tokens: 600
current_state: matches
---

# Long work answers 202

A request that cannot finish inside a sensible timeout does not hold the connection
open. It accepts the work, enqueues it, and tells the client where to look.

```ruby
def create
  export = current_user.exports.create!(status: :queued)
  GenerateExportJob.perform_later(export.id)

  response.headers["Location"] = api_v1_export_url(export)
  render json: ExportSerializer.one(export), status: :accepted
end
```

**`202` means accepted, not done.** The body describes the work, not its result, and
`Location` points at a resource the client can poll. Answering `200` with a
placeholder result teaches every client that a success means nothing.

**The status resource is a real endpoint.** `GET /v1/exports/:id` returns the same
serializer with a `status` field and, when finished, a link to the output. It is not a
special-cased polling route — it is the resource, and it exists before the job runs.

**A failed job is a completed request with a failed resource.** The `202` already
succeeded, so failure is reported in the status resource: a `status` of `failed` and a
`problem` object in the same shape as any other error
([error-envelope](error-envelope.md)). Never a `500` on the poll — the poll worked.

**Enqueue after commit, and pass the id.** Both are already the rule —
[jobs](jobs.md) — and both matter more here, because a job that starts before the
transaction commits will not find the record it was told to work on.

**The client is told to back off.** The contract states a polling interval, and the
poll endpoint is rate-limited like any other. A client polling in a tight loop is a
client nobody told otherwise.

**Which endpoints are async is a contract decision, not a runtime one.** An endpoint
does not sometimes return `201` and sometimes `202` depending on size — that is two
response shapes on one route and every client has to handle both. Pick per endpoint
and write it down.
