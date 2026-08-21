# Primary Keys Follow the Database

**Status:** Accepted

**Context:**
Needed to choose a primary key strategy. The answer is not the same on both
databases this app could have been generated for: PostgreSQL has a native `uuid`
type and `gen_random_uuid()`, MySQL has neither.

**Decision:**
UUID primary keys on PostgreSQL, using the built-in `gen_random_uuid()` — no
`pgcrypto` extension is needed on PostgreSQL 13+. Rails' default bigint primary
keys on MySQL and MariaDB.

Which one this app has is on the Tech Stack line of `CLAUDE.md`, and the working
conventions for each are in
[`../rules/database-conventions.md`](../rules/database-conventions.md).

**Consequences:**
- (+) On PostgreSQL: no ID guessing or enumeration, safe for distributed systems,
  IDs can be generated client-side
- (+) On MySQL: no type shim to own, smaller indexes, and `t.references` behaves
  the way every Rails guide says it does
- (-) On PostgreSQL: larger storage (16 bytes vs 4-8) and no natural ordering,
  mitigated with `implicit_order_column`
- (-) On MySQL: sequential IDs enumerate, so a public URL needs a slug or a
  random token rather than the key
- (-) The two flavours differ in a convention, not just in configuration, so the
  rule file has two halves and a migration between databases is not a config
  change
