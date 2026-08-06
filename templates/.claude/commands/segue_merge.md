---
description: Merge a closed segue's findings back into this workstream
argument-hint: [thread file path, optional]
---

# Segue merge

1. Find the thread: `$ARGUMENTS` if given, else the most recently modified `.llm/threads/*.md` with `status: closed`. None closed → say so (check whether one is still `open`) and stop.
2. Read **only the findings tail**, not the discussion:
   - `grep -n '^## FINDINGS' <file>` to get the line number.
   - `Read` the file with `offset` set to that line.
   - Do not read above it. The discussion log is exactly the context this session was kept clean of.
3. Restate in 3-6 lines: what was settled, what changed about the plan, what is next. Flag any ASSUMPTION items as still unverified.
4. Update the workstream plan/task doc if one exists, so the findings survive this session.
5. Set the thread's frontmatter `status: merged`.
6. Resume the workstream from `PATH FORWARD` step 1 — but if the findings contradict work already committed on this branch, stop and say so before editing.
