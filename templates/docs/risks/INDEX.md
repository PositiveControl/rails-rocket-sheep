# Accepted risks

**Status:** Current

Every known way a shipped change can hurt us that we chose not to fix yet: one file
per risk, and one line per file below. It exists so a risk accepted in one PR is still
in sight when someone changes that code months later, and so nobody is surprised when
one bites.

**Looking for risks near your change?** `grep -l "<path or keyword>" docs/risks/*.md`,
or read the list below. `/task_plan` does this for the files a plan touches.

## What earns an entry

A risk is a way the change can **fail in production**: wrong or lost data, money
moved wrongly, a leak, an outage, a customer-visible break. It is a known way, and the
team chose to ship without fixing it. Style, naming, "could be cleaner", missing
polish and a dropped nitpick are not risks. When in doubt, ask: *if this happened in
production, would someone have to clean it up?*

They come from these places:

- **Planning:** a design doc's or task plan's risk the developer approves going ahead with
- **Review:** a real finding dropped as not worth fixing now (`/implement`'s pre-PR review,
  `/pr_comment_resolver`), not one dropped as wrong
- **Autopilot:** any of the above taken by policy, recorded the same way and listed
  under the slice's *Risks accepted* in the autopilot log

## Recording a risk

1. **Look first.** `grep -il` the area's paths and key words across `docs/risks/`. A
   risk that already covers it gets a dated line under *History* and any change to
   its text. Do not write a second file for it. A related but different risk is a new
   file that links the other.
2. **Otherwise write** `docs/risks/YYYY-MM-DD-<slug>.md`, the slug naming the failure:

   ```markdown
   # <The failure, as it would be reported: "Order totals drift from an edited line item">

   **Status:** open
   **Accepted:** YYYY-MM-DD by <developer, or "autopilot (gate <id>)"> in <PR or issue link>
   **Area:** `app/services/foo.rb`, `app/controllers/admin/items_controller.rb`
   **Revisit when:** <the trigger: a volume, a feature, a date, "before launch">

   ## The risk
   What goes wrong, how it happens, how likely, how bad.

   ## Why accepted
   What fixing it now would cost, and why that lost.

   ## How we would notice
   The symptom, a query or a check that shows it happened, any mitigation in place.

   ## History
   - YYYY-MM-DD accepted in <PR>
   ```

   **Area** lists the paths a change to which should make someone look again. Globs
   are fine (`app/models/billing/*.rb`).
3. **Add or update its line** in the list below, keeping it sorted by file name:
   `- [<title>](<file>) — <status>`.
4. **Commit it with the change that accepts it.** The risk ships, and is reviewed, in
   the same PR.

**Status** is one of:

- `open` — accepted and still possible
- `retired` — fixed, or the code is gone. Add a *History* line naming the PR.
- `realized` — it happened. Add a *History* line linking the issue or the
  write-up of what happened.

Files are never deleted: a retired or realized risk is the record of why.

`bin/lint-docs` checks that every file here has one line below with its status, and
that every line names a file that exists. This file merges with git's `union` driver
(`.gitattributes`), so two branches that each add a line merge cleanly. A merge that
leaves a duplicate line, or two lines for one file after a status change, fails the
lint until one is removed.

## Risks

<!-- risks:start -->
<!-- risks:end -->
