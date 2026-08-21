---
id: database-conventions
title: Database conventions — UUIDs, foreign keys, indexes
applies_to: ["db/migrate/**/*.rb", "db/schema.rb", "app/models/**/*.rb"]
triggers: ["UUID", "primary key", "gen_random_uuid", "foreign key", "add_foreign_key", "index", "composite index", "t.uuid", "parent_id"]
see_also: ["safe-migrations", "n-plus-one"]
tokens: 150
---

# Database conventions

- **IDs:** UUIDs for all tables. Wired through the generators — `rails g model`
  does the right thing automatically. PostgreSQL `gen_random_uuid()`, no pgcrypto
  extension needed.
- **Foreign keys:** `t.uuid :parent_id` plus an explicit `add_foreign_key`.
- **Indexing:** composite indexes for frequently filtered column pairs.
- **Ordering:** UUIDs have no natural order — `implicit_order_column` is set.

Rationale and consequences: [ADR 0002](../adr/0002-uuid-primary-keys.md).
Applying any of this to a live table: [safe-migrations](safe-migrations.md).
