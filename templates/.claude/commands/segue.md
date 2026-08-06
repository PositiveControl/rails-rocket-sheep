---
description: Pause the workstream and open an isolated discussion thread
argument-hint: <topic or question to discuss>
---

# Segue

Topic: $ARGUMENTS

The user wants to stop workstream execution and discuss `$ARGUMENTS` in a **separate session**, so this session's context stays clean. Your job here is only to write the handoff brief and stop.

## Steps

1. Resolve the thread dir: `mkdir -p .llm/threads` in the primary working directory.
2. Pick a filename: `.llm/threads/YYYY-MM-DD-<short-slug>.md` (today's date, slug from the topic). If that path already exists, append `-2`, `-3`, ...
3. Write the thread file:

```markdown
---
title: <topic restated as a question if it is one>
date: <YYYY-MM-DD>
status: open
branch: <current git branch>
session: <this session's id if known, else omit>
---

## Handoff brief

### Workstream
<2-5 lines: what we are building, the goal, the task/PR/issue if there is one>

### Where we stopped
<Concrete state: files touched so far, what works, what does not, last command run and its result. Enough that a fresh session needs no other context.>

### Question to settle
<The topic, sharpened. What decision or theory the segue must resolve.>

### Constraints / prior decisions
<Anything already ruled in or out, so the segue does not re-litigate it. Omit the section if none.>

## Discussion log

## FINDINGS

## PATH FORWARD
```

Fill the brief from *this* session's actual context — not guesses. Be specific about file paths and line numbers; the segue session can read code but cannot read this conversation.

4. Tell the user, in this shape:

```
Thread: .llm/threads/<file>.md

Open a new terminal tab in <primary working dir>, run `claude`, then `/segue_resume`.
Come back here and run `/segue_merge` when the segue is closed.
```

5. **STOP.** Do not continue the workstream. Do not start discussing the topic here — that is the whole point. Do not edit code. End the turn after the message above.
