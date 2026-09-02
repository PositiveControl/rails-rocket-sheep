---
id: safe-migrations
title: Safe migrations — never lock a live table
applies_to: ["db/migrate/**/*.rb"]
triggers: ["migration", "add_column", "add_index", "backfill", "rename column", "remove column", "ignored_columns", "concurrently", "disable_ddl_transaction", "lock table", "deploy blocked"]
see_also: ["deletes", "database-conventions"]
modes: [ web, api ]
tokens: 500
current_state: matches
---

# Safe migrations

The rules that keep a deploy from locking a table:

- Add a column with a default in one migration, backfill in another. Never
  backfill in the same migration that adds the column.
- Add indexes with `algorithm: :concurrently` and `disable_ddl_transaction!` —
  **PostgreSQL only.** On MySQL that argument raises `ArgumentError`; MySQL 8
  builds indexes online by default, so plain `add_index` is the safe form there.
  Which database this app runs is on the Tech Stack line of `CLAUDE.md`.
- Remove a column in two deploys: `ignored_columns` first, then the drop.
- Never rename a column on a live table. Add, dual-write, migrate, drop.

```ruby
# PostgreSQL
class AddIndexToOrders < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :orders, [:user_id, :created_at], algorithm: :concurrently
  end
end

# MySQL — online by default, no special casing
class AddIndexToOrders < ActiveRecord::Migration[8.0]
  def change
    add_index :orders, [:user_id, :created_at]
  end
end
```

**The split is not theoretical.** An audited MySQL app has 126 migrations adding an
index and not one `algorithm: :concurrently`, because on MySQL that argument would
have raised. Copying the PostgreSQL form onto MySQL does not degrade quietly — it
fails the migration. Read the Tech Stack line before writing either.

The two-migration rules are the ones that actually get skipped: the same audited app
backfills in the migration that adds the column twice.
