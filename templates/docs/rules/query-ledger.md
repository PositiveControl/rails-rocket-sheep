---
id: query-ledger
title: Every query shape the suite emits has a reviewed line in db/queries.yml
applies_to: ["db/queries.yml", "app/models/**/*.rb", "app/queries/**/*.rb", "db/migrate/**/*.rb"]
triggers: ["query ledger", "db/queries.yml", "db:queries", "EXPLAIN", "query plan", "sequential scan", "seq scan", "unreviewed", "unknown shape", "is this query indexed"]
see_also: ["n-plus-one", "database-conventions", "query-objects", "scopes"]
modes: [ web, api ]
tokens: 950
current_state: matches
---

# The query ledger

`db/queries.yml` lists every distinct SQL shape the test suite emits from `app/`, each
with a one-line `review:`. It is a build output with one human column: the list is
generated, the review lines are kept across regenerations, and CI fails on a shape the
file does not know or a review left empty.

```bash
bin/rails db:queries          # run the suite, merge new shapes in with an empty review
bin/rails db:queries:explain  # EXPLAIN each unreviewed entry, with its tables' indexes
bin/rails db:queries:check    # exit 1 on an unknown shape or an empty review — what CI runs
```

```yaml
- sql: SELECT "orders".* FROM "orders" WHERE "orders"."user_id" = ? ORDER BY "orders"."created_at" DESC
  from: app/models/user.rb
  review: index_orders_on_user_id_and_created_at
- sql: SELECT "users".* FROM "users" WHERE "users"."admin" = ?
  from: app/queries/admin_roster.rb
  review: "no index: boolean over a table that stays small, revisit at 50k users"
```

**A gate cannot decide that a query is good, only that someone looked.** A test
database holds a few hundred rows, and on a few hundred rows a sequential scan is the
right plan, so `EXPLAIN` in CI would fire on every small table in every PR. What the
ledger holds is that the question was answered once and the answer written next to the
query. The plan itself is not stored — a plan from a development database is a hint,
not a fact.

**The review line is checked, not trusted.** It must either name an index that exists
in `db/schema.rb`, or start with `no index:` and give the reason. "fine" fails. An index
that is later dropped fails too, which is the right outcome: the review is stale.

**Write the line with the plan in front of you.** `db:queries:explain` prints the plan
and the indexes on the tables it touches, one screen per entry. Name the index the plan
uses; when it uses none, say why that is right today and at what size to revisit.

**A shape, not a query.** Literals become `?`, so two queries differing only in values
are one entry. Filter and sort combinations produce distinct shapes, and that is
correct: each is a different plan and each gets a line.

**Asymmetric, so it never flaps.** A shape the suite emits and the file lacks fails. A
shape the file has and the suite did not emit is pruned by `db:queries`, never failed
by `check`. Only frames under `app/` are recorded, so fixtures, schema loads and the
framework's own traffic add nothing, and a Rails upgrade cannot produce a wave of
entries.

**A query is recorded where it is loaded, not where it is written.** The frame is the
first one under `app/` when the rows are fetched: a scope loaded by a controller, job or
view is attributed to that file, and a scope loaded only inside a unit test records
nothing, because no application code ran it. An untested path records nothing either.
A query cannot be reviewed without a test that runs it the way the app does, so the
pressure to review is pressure to test — the same property as the API contract.

Rationale and consequences: [ADR 0015](../adr/0015-a-query-is-reviewed-once-and-the-ledger-remembers.md).
