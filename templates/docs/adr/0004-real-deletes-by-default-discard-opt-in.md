# Real Deletes by Default, Discard Opt-In

**Status:** Accepted

**Context:**
Soft deletion as a house style means every query, association, and authorization
check against a discardable model must remember `.kept`, and forgetting is silent.
PaperTrail — already installed — can reify a destroyed record, which covers the
common "an admin deleted the wrong thing" case without that tax.

**Decision:**
`destroy` is the default. Discard is installed and added to a model only when
restoration is a user-facing feature, an audit obligation requires the row to
survive, or foreign keys point at it from records that must stay valid. Never
`default_scope -> { kept }` — an escapable scope is the whole reason Discard omits
one.

**Consequences:**
- (+) Most queries carry no soft-delete tax
- (+) The models that do use it did so for a stated reason
- (+) PaperTrail reify covers accidental deletion without a schema change
- (-) Restoring a hard-deleted record is console surgery and won't restore associations
- (-) Requires judgement per table rather than a blanket rule
