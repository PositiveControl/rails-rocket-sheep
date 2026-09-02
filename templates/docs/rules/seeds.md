---
id: seeds
title: Seeds — idempotent, and kept in step with the schema
applies_to: ["db/seeds.rb", "db/seeds/**/*.rb"]
triggers: ["seed", "db:seed", "seeds.rb", "find_or_create_by", "demo data", "sample data", "idempotent", "SEED_ADMIN_PASSWORD", "SEED_ALLOW_PRODUCTION"]
see_also: ["database-conventions", "testing"]
modes: [ web, api ]
tokens: 420
current_state: matches
---

# Seeds

`db/seeds.rb` is the one description of what a fresh checkout needs to be a working
system. It is part of the schema's contract, not a scratch file.

- **Idempotent, always.** `bin/rails db:seed` must be safe to run any number of
  times. Guard every insert — `Model.exists?(...)` then return, `find_or_create_by!`,
  or an upsert. Never a blind `create!` that duplicates on a second run.
- **Keep it in step.** Adding a model, changing a process, or introducing a
  dependency that production data relies on means the seeds change in the same PR.
  Dev data that diverges from what a real environment expects is a bug you only
  find in production.
- **Guard models that may not exist yet** — `unless defined?(User)` — so a partial
  checkout still seeds what it can.
- **Never seed production by accident.** The guard stays:
  `Rails.env.production? && ENV["SEED_ALLOW_PRODUCTION"].blank?`.
- **No secrets in the file.** Passwords come from ENV or are generated and printed
  once, never hardcoded.

Seed data is not test data — test fixtures are intentionally empty and live
elsewhere: [testing](testing.md). Column and ID conventions: [database-conventions](database-conventions.md).
