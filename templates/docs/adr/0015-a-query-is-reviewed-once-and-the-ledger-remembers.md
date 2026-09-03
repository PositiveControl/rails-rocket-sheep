# A Query Is Reviewed Once, And The Ledger Remembers

**Applies to:** both modes. Every app with a database emits queries; whether the
response is HTML or JSON does not change the plan.

**Status:** Accepted

**Context:**
Bullet answers "is this query repeated per row". Nothing answers "should this query
exist in this shape at all", and a machine cannot: the answer depends on cardinality,
growth, and what else touches the table. The tempting gate — `EXPLAIN` in CI, fail on
a sequential scan — is wrong on purpose-built grounds: a test database holds a few
hundred rows, and on a few hundred rows the planner picks a sequential scan and is
right to. That gate would fire on every small table in every PR, get disabled, and
take the useful gates with it.

What a machine *can* hold is the fact that a person answered the question once and
wrote the answer down next to the query.

**Decision:**
`db/queries.yml` is committed and it is a build output with one human column. Running
the suite with the recorder armed produces every distinct SQL shape application code
emits, keyed by the shape and the first `app/` frame that emitted it. `bin/rails
db:queries` merges new shapes in with an empty `review:` and keeps the lines already
written; `bin/rails db:queries:check` exits non-zero on a shape the file lacks or a
review that is empty, and CI runs that. A review line is valid only when it names an
index `db/schema.rb` has or starts with `no index:` and says why, so the line is
checkable in a diff — the same bar a pattern has to clear to be a rule at all.
`bin/rails db:queries:explain` prints the plan and the indexes for every unreviewed
entry, so writing the line costs one screen of reading.

The check is asymmetric. An emitted shape the file lacks fails; a ledgered shape the
suite did not emit is pruned on the next `db:queries` and never failed. A test whose
branch runs only sometimes therefore adds its query once and never flaps.

It is the same mechanism as the API contract
([ADR 0013](0013-the-api-contract-is-generated-from-its-tests.md)): generated from the
tests, committed, `check` fails on drift. Conventions are in
[`../rules/query-ledger.md`](../rules/query-ledger.md).

**Consequences:**
- (+) Every query in the app was looked at by someone, and the diff shows exactly
  which ones are new. A reviewer reads the `db/queries.yml` hunk and knows where to
  spend attention
- (+) A dropped index fails the review that named it, so the ledger cannot quietly
  outlive the schema it describes
- (+) An untested query records nothing, so the pressure to review is pressure to
  test, which is the right direction for that pressure to run
- (-) The gate needs a database and a suite run, so it is its own CI job rather than
  a check in `bin/gates`, and it never runs at pre-push
- (-) A mature app carries several hundred entries. That is the point — each was
  looked at — but the file is only reviewable because entries are sorted and hold
  nothing but the shape, the frame and the line
- (-) A query is attributed to the `app/` frame that loads it, so a scope exercised
  only by a model test is not ledgered until a controller, job or view loads it
  under test. That is the plan that matters, but model tests alone arm nothing
- (-) The review line records that someone decided, not that they decided well.
  Whether the named index is the right one is still a reviewer's call, and CI cannot
  make it
