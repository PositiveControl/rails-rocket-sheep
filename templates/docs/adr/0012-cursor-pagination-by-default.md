# Cursor Pagination by Default

**Applies to:** API mode. Server-rendered mode paginates with Pagy, which renders
numbered pages — [`../rules/pagination.md`](../rules/pagination.md).

**Status:** Accepted

**Context:**
Offset pagination is what everyone reaches for and it has two defects that only show
up in production: a deep `OFFSET` makes the database walk and discard every skipped
row, and a write between two requests shifts the window, so a client scrolling a list
sees a row twice or never sees it at all.

A JS client consuming this API mostly scrolls forward through lists. It rarely needs
page seven by number, and when it does it needs a total, which cursors cannot give
it.

**Decision:**
Cursor pagination is the default for every collection endpoint. The cursor encodes
the sort key plus a unique tiebreak and nothing else; it is Base64 and documented as
opaque. `per_page` is clamped on `Api::V1::BaseController`, because the value comes
from the internet.

Offset is permitted as a named per-endpoint exception: a screen with numbered pages
takes `page`/`per_page`, returns `total_count`, and says in the contract that deep
pages are expensive and results may shift. Named, written down, not a default.

On PostgreSQL the primary key is a `uuid` and has no order
([ADR 0002](0002-primary-keys-follow-the-database.md)), so the key is
`(created_at, id)` — the sort column, plus the id to break ties. Conventions are in
[`../rules/cursor-pagination.md`](../rules/cursor-pagination.md).

**Consequences:**
- (+) Page cost is constant at any depth, and it is an index range scan rather than a
  scan-and-discard
- (+) A row written between two requests cannot duplicate or hide a row in the next
  page
- (+) An opaque cursor leaves the sort implementation free to change
- (-) No page numbers, no jump-to-page, and no total without a second query. A UI that
  needs those needs the named exception
- (-) Two pagination styles exist in one API, and a client has to know which an
  endpoint uses. The contract has to say
- (-) The tiebreak is not optional and its absence is silent: two rows sharing a
  `created_at` at a page boundary are returned twice or skipped, with no error and no
  failing test unless one is written for it
- (-) A cursor is only valid for the sort it was issued under, so changing sort has to
  reset it
