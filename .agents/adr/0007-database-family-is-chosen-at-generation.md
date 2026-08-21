# The database family is chosen at generation, and only primary keys diverge

## Context

The template was PostgreSQL-only, and not by decision — by accumulation.
`config/database.yml.tt` hardcoded `adapter: postgresql`, the Kamal accessory
hardcoded `postgres:16`, the Dockerfile installed `libpq-dev`, and
`docs/faq.md` said porting to MySQL "means rewriting `config/database.yml` and
choosing a different primary key strategy" — which was true, and was also the
entire list.

MySQL is what a large share of existing Rails shops already run. For them the
choice was not "PostgreSQL or MySQL", it was "this template or not".

`rails new` already asks the question. `--database=` picks the gem, the CI
service, and the adapter before `template.rb` gets control. There was never a
reason to ask twice.

## Decision

`template.rb` reads `options[:database]`, normalises it to a **family**, and
branches on the family — not the adapter. PostgreSQL, MySQL, MariaDB, mysql2 and
trilogy are all supported; mysql2 and trilogy differ in the driver and in nothing
a convention cares about.

Anything other than those raises before a single file is written, with the
working invocations in the message. SQLite is a deliberate no: the Solid Stack
wants four databases and no deployment target here is set up for it.

The one thing that genuinely diverges is primary keys:

| | PostgreSQL | MySQL / MariaDB |
|---|---|---|
| primary key | `uuid`, `gen_random_uuid()` | Rails' default `bigint` |
| foreign key | `t.uuid :parent_id` + `add_foreign_key` | `t.references :parent, foreign_key: true` |
| ordering | `implicit_order_column = :created_at` | natural |

MySQL has no native uuid type. Faking one means a `char(36)` column, a default
expression, and a type shim Rails does not ship — roughly eighty lines to own
forever so that two databases could share one sentence in a rule file. A MySQL
app gets bigint, and the rule file gets two halves.

## Consequences

Accepted:

- **One rule has two halves, and an agent has to know which app it is in.**
  `docs/rules/database-conventions.md` routes off the Tech Stack line in
  `CLAUDE.md`. That is one indirection more than "UUIDs for all tables", and if
  an agent reads the wrong half it will write a foreign key that does not match.
  The mitigation is that the wrong half fails loudly at migration time.
- **`safe-migrations` is now adapter-specific too.** `algorithm: :concurrently`
  is correct on PostgreSQL and raises `ArgumentError` on MySQL, where DDL is
  online by default. Both are in the rule.
- **Bigint keys enumerate.** A convention this template used to get for free —
  no ID guessing — is now something a MySQL app has to think about. The rule says
  so where the decision is made, rather than only here.
- **A rule and a command had to become database-aware without ERB.**
  `docs/rules/*` and `.claude/commands/*` are copied verbatim so
  `bin/rocket-sheep-update` can three-way merge them ([ADR
  0005](0005-updates-are-a-three-way-merge-from-the-stamp.md)). Turning them into
  `.tt` would have bought cleaner prose and cost them their upgrade path, so they
  state both flavours instead. That trade is why the rule reads the way it does.
- **`docs/sop/extract-database-and-storage.md` stayed a PostgreSQL walkthrough**
  with a substitution table for MySQL, rather than becoming two procedures. A
  260-line document duplicated is a document that drifts.
- **Only PostgreSQL is verified end to end.** Neither flavour's generated app has
  had `bin/test` run against a live server in this repo's history; MySQL now
  carries the same debt with none of the field use. Tracked in
  `docs/inventory.md`.

## Revisit when

Someone wants UUID keys on MySQL badly enough to own the shim, or a third family
is asked for. A third family is the point at which the `POSTGRESQL` boolean
should become a proper predicate and the branches should be reviewed as a set,
rather than each grown in place.
