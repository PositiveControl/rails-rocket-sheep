# Service Object Pattern

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
