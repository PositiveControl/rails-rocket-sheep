# Architecture Decision Records

This document tracks important architectural decisions for the project.

## ADR-001: Rails 8 Solid Stack

**Status:** Accepted

**Context:**
Needed to choose infrastructure for background jobs, caching, and WebSockets.

**Decision:**
Use Rails 8 Solid Stack (Solid Queue, Solid Cache, Solid Cable) - all database-backed.

**Consequences:**
- (+) No Redis dependency - simpler infrastructure
- (+) Built into Rails 8 - well supported
- (+) Database-backed - reliable, transactional
- (-) Slightly higher database load
- (-) May need separate databases at scale

---

## ADR-002: UUID Primary Keys

**Status:** Accepted

**Context:**
Needed to choose primary key strategy.

**Decision:**
Use UUIDs (via PostgreSQL `pgcrypto`) for all primary keys.

**Consequences:**
- (+) No ID guessing/enumeration attacks
- (+) Safe for distributed systems
- (+) Can generate IDs client-side
- (-) Larger storage (16 bytes vs 4-8 bytes)
- (-) No natural ordering (mitigated with `implicit_order_column`)

---

## ADR-003: Service Object Pattern

**Status:** Accepted

**Context:**
Controllers were getting fat with business logic.

**Decision:**
Use `ApplicationService` base class with Result pattern for all business logic.

**Consequences:**
- (+) Testable business logic
- (+) Consistent return values (Result object)
- (+) Single responsibility
- (-) More files to manage
- (-) Learning curve for new developers

---

## ADR-004: Soft Deletes with Discard

**Status:** Accepted

**Context:**
Needed ability to "undo" deletions and maintain audit trail.

**Decision:**
Use Discard gem for soft deletes on models that need it.

**Consequences:**
- (+) Can restore deleted records
- (+) Maintains referential integrity
- (+) Audit trail preserved
- (-) Must remember to use `.kept` scope
- (-) Database grows over time

---

## ADR-005: Slim Templates

**Status:** Accepted

**Context:**
Needed to choose a templating language.

**Decision:**
Use Slim instead of ERB for all views.

**Consequences:**
- (+) Cleaner, more readable templates
- (+) Enforces proper indentation
- (+) Less visual noise than ERB
- (-) Learning curve for ERB developers
- (-) Some Tailwind syntax requires workarounds (see design-patterns.md)

---

## Template: New ADR

```markdown
## ADR-XXX: [Title]

**Status:** Proposed | Accepted | Deprecated | Superseded

**Context:**
What is the issue we're addressing?

**Decision:**
What is the change we're proposing?

**Consequences:**
- (+) Positive consequence
- (-) Negative consequence
```
