# Service Object Pattern

**Status:** Accepted

**Context:**
Controllers were getting fat with business logic.

**Decision:**
Use `ApplicationService` base class with Result pattern for all business logic.

The Result has three states, not two. `success` and `failure` are the obvious pair; a
write can also be correct, permitted, and still not safe to complete until the caller
confirms something that moved underneath it — a cart whose prices changed between
loading and checkout is the ordinary case, not an edge case. Forcing that into
`failure` tells the caller to fix its input when there is nothing wrong with its
input, so `needs_confirmation(**details)` returns a third state and `confirm` carries
what the client has to see. `success?`, `failure?` and `needs_confirmation?` are
mutually exclusive.

In API mode a controller maps the third state to `409` with its own problem type
([ADR 0009](0009-errors-are-problem-documents.md)); in server-rendered mode it
re-renders with the changes shown. The service never knows a status code exists.
Conventions are in [`../rules/service-objects.md`](../rules/service-objects.md).

**Consequences:**
- (+) Testable business logic
- (+) Consistent return values (Result object)
- (+) Single responsibility
- (+) A confirmation round-trip is expressible without an exception or a magic error
  string
- (-) More files to manage
- (-) Learning curve for new developers
- (-) A caller written for two states treats the third as a failure. That is safe, and
  wrong in a way somebody notices, but it is not caught by the type
