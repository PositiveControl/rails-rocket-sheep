# Rails 8 Solid Stack

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
