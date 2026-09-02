---
id: safe-migrations
title: Safe migrations — never lock a live table
applies_to: ["db/migrate/**/*.rb"]
triggers: ["migration", "add_column", "add_index", "backfill", "rename column", "remove column", "ignored_columns", "concurrently", "disable_ddl_transaction", "lock table", "deploy blocked"]
see_also: ["deletes", "database-conventions"]
tokens: 370
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
