---
description: "Write findings and path forward, closing the segue thread"
argument-hint: "[thread file path, optional]"
---

# Segue close

Resolve the thread file the same way `/segue_resume` does (argument, else most recent `status: open`).

Fill in the two empty sections. Everything the workstream will act on must live here — `/segue_merge` reads **only** from `## FINDINGS` onward, by design.

```markdown
## FINDINGS
- <what we established, one line each. Evidence attached: file:line, test name, command output. Mark anything still unverified as ASSUMPTION.>
- <theories tested and rejected, and why — this is what stops the workstream re-treading them>

## PATH FORWARD
1. <concrete next actions, in order, with the files each touches>
2. ...

Out of scope / deferred: <what we deliberately are not doing>
Plan changes: <how this differs from the plan the workstream had before the segue, if it does>
```

Then set frontmatter `status: closed`.

Rules:
- No conclusion without evidence or an explicit ASSUMPTION tag.
- If the question did not get settled, say that plainly in FINDINGS and make PATH FORWARD the next step toward settling it. A closed thread that pretends to certainty is worse than an open one.
- Revert any experimental edits still in the working tree, or list them under a `Left in tree:` line so the workstream is not surprised.

Finish with: `Closed. Back in the workstream session, run /segue_merge.`
