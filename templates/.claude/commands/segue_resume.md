---
description: "Pick up an open segue thread in this fresh session"
argument-hint: "[thread file path, optional]"
---

# Segue resume

1. Find the thread:
   - If `$ARGUMENTS` names a file, use it.
   - Otherwise list `.llm/threads/*.md`, and pick the most recently modified one with `status: open` in its frontmatter. If several are open, show the list and ask which.
   - If none are open, say so and stop.
2. Read the whole thread file.
3. Read the code the brief points at before saying anything — the brief names paths for a reason.
4. Give the user a short orientation: the question to settle, current state, and your first read on it. Then discuss.

## While in the segue

This session exists to think, argue, and test. Freely: read code, run tests, spike throwaway changes, try theories in the console. Same working tree as the workstream — so before editing anything the brief listed as workstream WIP, say what you are about to touch and revert experiments when done.

Keep `## Discussion log` in the thread file updated as you go: one terse line per real conclusion or dead end, not a transcript. Append at natural pauses, not every turn.

Do not resume the workstream from here. When the question is settled, the user runs `/segue_close`.
