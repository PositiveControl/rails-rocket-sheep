---
description: Abandon a segue that yielded nothing; record why and skip the merge
argument-hint: [thread file path, optional]
---

# Segue kill

For segues that went nowhere: no usable findings, no path forward. The thread is closed as dead, the workstream resumes without a merge.

1. Resolve the thread the same way `/segue_resume` does (argument, else most recent `status: open`). None open → say so and stop.
2. Confirm with the user: "Kill <file> — no findings to merge?" A segue that settled anything, even negatively ("X is impossible because Y"), deserves `/segue_close` instead — a proven dead end is a finding.
3. Write the epitaph under `## FINDINGS`:

```markdown
## FINDINGS
- KILLED <YYYY-MM-DD>: <one line — why this went nowhere (question dissolved, superseded, wrong premise, ran dry)>
- <dead ends actually tried, one line each, if any — so the workstream never re-treads them>

## PATH FORWARD
None — killed. Workstream continues on its prior plan, unchanged.
```

4. Set frontmatter `status: killed`.
5. Revert any experimental edits still in the working tree, or list them under a `Left in tree:` line.
6. Finish with:

```
Killed. Resume the workstream directly — no /segue_merge needed.
The thread file records why, so the question doesn't get reopened blind.
```

Rules:
- Never delete the thread file — a recorded dead end is cheap insurance.
- `/segue_merge` ignores `status: killed` threads by design; the workstream plan is already correct.
