---
id: database-conventions
title: Database conventions — primary keys, foreign keys, indexes
applies_to: ["db/migrate/**/*.rb", "db/schema.rb", "app/models/**/*.rb"]
triggers: ["UUID", "bigint", "primary key", "gen_random_uuid", "foreign key", "add_foreign_key", "index", "composite index", "t.uuid", "t.references", "parent_id"]
see_also: ["safe-migrations", "n-plus-one"]
tokens: 550
---

# Database conventions

**Primary keys depend on which database this app runs.** The Tech Stack line at
the top of `CLAUDE.md` names it. Read that, then follow one half of this file —
not both.

## PostgreSQL — UUID primary keys

- **IDs:** UUIDs on every table, wired through the generators, so `rails g model`
  does the right thing on its own. `gen_random_uuid()` is built into PostgreSQL
  13+; no pgcrypto extension.
- **Foreign keys:** `t.uuid :parent_id` plus an explicit `add_foreign_key`. Never
  `t.references :parent` without a type — it silently emits a bigint that will
  not match the parent's key.
- **Ordering:** UUIDs have no natural order, so `ApplicationRecord` sets
  `implicit_order_column = :created_at`. Leave it alone.

## MySQL and MariaDB — bigint primary keys

- **IDs:** Rails' default bigint. MySQL has no native uuid type, and faking one
  costs a `char(36)` index for nothing this app needs.
- **Foreign keys:** `t.references :parent, foreign_key: true`. The type is
  inferred and correct — this is the form the PostgreSQL half warns against, and
  here it is the right one.
- **Ordering:** bigint keys order naturally. There is no `implicit_order_column`
  and none is needed.
- **Sequential IDs enumerate.** Do not put one in a public URL you would mind
  being walked; use a slug or a separate random token.

## Both

- **Indexing:** composite indexes for frequently filtered column pairs.
- **Live tables:** applying any of this to a table with rows in it —
  [safe-migrations](safe-migrations.md).

Rationale and consequences: [ADR 0002](../adr/0002-primary-keys-follow-the-database.md).
Applying any of this to a live table: [safe-migrations](safe-migrations.md).
