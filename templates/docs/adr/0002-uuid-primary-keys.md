# UUID Primary Keys

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
