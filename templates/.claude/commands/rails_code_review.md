# Rails Code Review

Thorough code review of a Rails 8 branch against `main`.

## Setup

First, gather context:

```bash
git fetch origin main
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
git log origin/main..HEAD --oneline
```

Diff alone not enough for context → read changed files in full. Also check related files (models, tests, routes) not changed but relevant to the diff.

*Note: diff huge → prioritize `app/models/`, `app/controllers/`, `app/services/`, `db/migrate/` over UI tweaks or locale files.*

$ARGUMENTS

---

## Review Standards

This app follows `CLAUDE.md` — it is the single source for conventions. This command reviews *against* those conventions; it does not restate them.

Stack:
- Rails 8 Solid Stack — Solid Queue, Solid Cache, Solid Cable, each on its own database
- PostgreSQL, UUID primary keys on every table
- Hotwire (Turbo Frames, Turbo Streams, Stimulus)
- Slim templates, Tailwind CSS
- Devise (Turbo-configured) + Petergate for roles
- Minitest + fixtures, VCR for HTTP recording
- `ApplicationService` + Result pattern for business logic
- `RegistryBase` for configuration entities
- Discard for soft deletes, PaperTrail for audit trail
- Pagy for pagination

Code style: double quotes, 2-space indent, trailing newline, empty line between methods and after guard clauses.

---

## Review Checklist

Work each section. Nothing relevant → skip the section.

### 1. Correctness & Business Logic

- Does the code do what it intends? Logic errors, off-by-one mistakes?
- Edge cases handled: nil values, empty collections, boundary conditions?
- State transitions correct and guarded against invalid sequences?
- Background jobs idempotent — safe to run twice?
- Services return a `Result`, and every caller checks `success?` before using `value`?

### 2. Security

- **Authorization**: every controller action checks authorization — Petergate `access_control` or a `before_action` guard. Flag any action with no permission check.
- **Strong Parameters**: `permit!` forbidden without documented justification. Params tightly scoped.
- **SQL Injection**: no string interpolation in `where` / `order` / `find_by_sql`. Parameterized queries or Arel only.
- **XSS**: `raw` and `html_safe` must be justified. User content escaped.
- **Mass Assignment**: `assign_attributes` / `update` use permitted params.
- **Sensitive Data**: no credentials, tokens, or PII in logs, comments, or hardcoded strings.
- **UUID enumeration**: UUID PKs prevent ID guessing — flag anywhere a sequential or predictable identifier is exposed instead.
- **Soft deletes**: discarded records must not leak through a query that forgot `.kept` — especially in authorization checks and API responses.

### 3. Performance

- **N+1 Queries**: check every `.each` over an ActiveRecord collection. Associations eager-loaded with `includes` / `preload` / `eager_load`? Bullet is enabled in development — an N+1 reaching review means it was ignored.
- **Missing Indexes**: new columns used in `WHERE`, `ORDER BY`, or as foreign keys need indexes, added in the same migration. Composite indexes for frequently combined filters.
- **UUID index cost**: UUID keys are 16 bytes and randomly ordered. Flag redundant or unused indexes on high-write tables.
- **Unbounded Queries**: `Model.all` or scopes without `.limit` on tables that grow need Pagy.
- **Counter Caches**: association counts displayed → counter cache or `.size`, never `.count` inside a loop.
- **Caching**: expensive or repeated computation → `Rails.cache` (Solid Cache). Cache keys nameable and expirable?
- **Background Jobs**: non-blocking work → Solid Queue. Job arguments must be small serializable primitives (record IDs, not AR objects) — Solid Queue is database-backed and fat arguments bloat the queue database.
- **PaperTrail volume**: `has_paper_trail` on a high-write model writes a `versions` row per change. Flag it on hot tables, or scope with `only:`.

### 4. Rails Conventions & Architecture

- **Fat models / thin controllers**: business logic in models or services, never controllers. Controllers orchestrate only.
- **Service objects**: multi-model or multi-step operations belong in `app/services/`, inheriting `ApplicationService`, returning `success` / `failure`. Flag a service that only wraps one `create!` — that's a layer for nothing.
- **Registries**: fixed sets of variants with per-variant attributes belong in a registry, not scattered constants or conditionals. Flag capability checks written as identity checks (`plan == "pro" || plan == "enterprise"` instead of `PlanRegistry.has_feature?`).
- **Concerns**: shared behaviour extracted, not copy-pasted. Pattern repeated 2–3 times → extract.
- **Scopes over class methods** for all queries.
- **RESTful routing**: custom actions genuinely non-CRUD, or should this be a new resource?
- **Callbacks**: avoid `after_save` / `after_create` for side effects that should be explicit (emails, notifications). Call them from a service.
- **UUID foreign keys**: `t.uuid :parent_id` with `add_foreign_key` — not `t.references` without a type, which silently produces a bigint mismatch.
- **Turbo / Hotwire**:
  - `turbo_stream_from` + `broadcast_*_to` for async updates, not polling
  - Frames for partial updates; Streams for multi-target or real-time
  - Stimulus uses `targets` / `values` / `actions`, not direct DOM queries
  - Reuse the generic `toggle_controller` / `modal_controller` rather than writing a third variant
- **Slim**: no Ruby logic beyond simple conditionals and iteration — extract helpers. Tailwind bracket classes need the `class=""` attribute form.

### 5. Testing

- Tests for all new public methods and controller actions?
- Happy path *and* key failure cases (invalid input, unauthorized access)?
- Fixtures satisfy uniqueness constraints and are named meaningfully — not `one` / `two`.
- Services tested through their `Result` — both `success?` and `failure?` branches, with `errors` asserted.
- External API calls recorded with VCR. No live network in tests.
- Minitest style: `assert_*`, plus `assert_difference` / `assert_raises` / `assert_redirected_to` where they fit.
- System tests for Turbo/Stimulus interaction.
- No skipped tests without a comment explaining why. No flaky test left "for later" — `CLAUDE.md` requires fixing immediately.
- Tests isolated; no dependence on execution order.

### 6. Code Quality

- **Naming**: snake_case methods/variables, CamelCase classes, SCREAMING_SNAKE_CASE constants.
- **Method length**: flag methods over ~15 lines or with complexity warranting extraction.
- **DRY**: duplicated logic across models, controllers, or views → extract.
- **Dead code**: removed features clean up routes, jobs, helpers, tests. No commented-out code — git has history.
- **Error handling**: rescue specific exception classes, never bare `rescue Exception`. Expected failures return `failure()`; genuinely exceptional conditions raise.
- **Logging**: errors logged with enough context to debug. Services use `log_error` / `log_info`. No `puts` in library code.
- **Comments**: only where *why* isn't obvious from the code.

### 7. Migrations

- Reversible (`change`, or explicit `up` / `down`)?
- New columns have appropriate defaults and null constraints?
- Indexes added in the same migration as the column?
- Data migration needed alongside the schema migration?
- **Large-table changes**: PostgreSQL takes an `ACCESS EXCLUSIVE` lock for many `ALTER TABLE` operations. Adding a column with a volatile default, adding a `NOT NULL` constraint, or creating an index without `algorithm: :concurrently` will block writes for the duration. Flag any of these on a table expected to be large, and require `disable_ddl_transaction!` where `concurrently` is used.
- Does the migration target the right database? Queue, cache, and cable have their own `migrations_paths` — a migration in the wrong directory silently applies to the wrong database.

---

## Output Format

### Summary
2–4 sentences: what changed, why, overall quality.

### Critical Issues
Must fix before merge: security vulnerabilities, data loss risks, broken functionality, missing authorization.

### Important Issues
Bugs, N+1 queries, missing tests on critical paths, architectural problems.

### Minor Issues
Style, naming, small improvements, optional refactors.

### Positive Observations
What's done well — specific, not generic.

---

Direct and specific. Reference file paths and line numbers. Show corrected snippets for non-obvious fixes. Nothing for a section → omit it. Signal over volume: a focused review with 5 real issues beats 20 nitpicks.
