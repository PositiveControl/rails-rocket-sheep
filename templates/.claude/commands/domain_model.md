---
description: "Sharpen this project's vocabulary, and record decisions as ADRs"
argument-hint: '<the term, decision, or area to sharpen>'
---

# Domain Model

Sharpen how this project talks about `$ARGUMENTS`, and write down what gets settled: the term in `docs/system/vocabulary.md`, the decision as an ADR in `docs/adr/`. The design interview is `/grill` and the deep doc pass is `/update_docs`; this is the vocabulary and the decisions those two keep running into. Pass a term, a decision, or an area: `/domain_model "what we mean by an account"`.

Active discipline, not a reading pass. Merely consulting the glossary is a habit every command already has; this one is for changing it.

## Instructions

### Step 1: Read what the project already says

`docs/system/vocabulary.md` for the terms, `docs/adr/` for the decisions in the area, and the code that uses either. Read before proposing: a term already defined is a term to use, not to redefine.

### Step 2: Challenge the language, out loud

Four moves. Use whichever the conversation earns, and say which one you are making.

| Move | What it looks like |
|---|---|
| **Challenge against the glossary** | The user's term conflicts with a definition already written. "The glossary says a *discard* leaves the row in place, but you seem to mean `destroy`. Which is it?" |
| **Sharpen fuzzy language** | One word covering two things. "You said *account*: do you mean the `User` who signs in, or the `Organization` that gets billed? Those are different tables." |
| **Invent the edge case** | Stress the relationship with a concrete scenario rather than an abstraction. "A user belongs to two organizations and one deletes their seat. Which of the two is the *account* now?" |
| **Cross-check the code** | The claim and the schema disagree. Say so with the file. "You said an order can be partially cancelled, but `Order#cancel!` sets one status for the whole record." |

The decisions are the user's. Finding the facts (schema, callers, existing definitions) is yours.

### Step 3: Write the term down as it settles

Straight into `docs/system/vocabulary.md`, in place, as each one resolves. Do not batch them to the end of the session: an unwritten agreement is one nobody can quote next week.

```markdown
**Discard**:
A row marked `discarded_at` and excluded by `.kept`, kept for restoration or audit.
_Avoid_: soft delete, archive, trash
```

Four rules the file lives by:

- **Be opinionated.** Several words for one concept → pick one, and list the losers under `_Avoid_`. A glossary that permits synonyms is a glossary that permits drift.
- **Keep definitions tight.** One or two sentences. Define what it *is*, not what it does.
- **Only terms specific to this project.** General programming vocabulary (timeout, retry, adapter) does not belong here however often the code says it.
- **No implementation detail.** It is a glossary, not a spec and not a scratch pad. A definition that names a method or a column has drifted into `docs/rules/` or an ADR.

### Step 4: Offer an ADR only when it earns one

All three must be true, and the answer is no when any one is missing:

1. **Hard to reverse** — changing your mind later costs something real.
2. **Surprising without context** — a future reader will look at the code and wonder why on earth it was done this way.
3. **The result of a real trade-off** — there were genuine alternatives, and one was picked for stated reasons.

Easy to reverse → it will just get reversed. Unsurprising → nobody will wonder. No alternative → there is nothing to record beyond "we did the obvious thing". Offer sparingly: an ADR per decision is how the directory becomes unreadable.

### Step 5: Write the ADR

One file per decision, next number, four digits, slug from the title:

```bash
ls docs/adr | tail -1        # highest number so far, increment it
```

`docs/adr/0009-<slug>.md`. The shipped eight are the shape: an H1 naming the decision, then **Status**, **Context**, **Decision**, **Consequences** as `(+)` and `(-)` lines. Shorter is fine — three sentences carrying the context, the decision, and the cost accepted is a complete ADR. Longer is not: an ADR nobody finishes reading records nothing.

**Rules say what to do; ADRs say why it was chosen.** The convention goes in `docs/rules/`, one per file with frontmatter; the reasoning and the accepted cost go here. A rule that argues with itself, or an ADR that tells you how to write the code, means the two got merged.

### Step 6: Index it

Add the ADR to `.llm/README.md` between the `adr` markers, one line: the link plus the decision it records. Terms need no index entry; `vocabulary.md` is already listed.

### Step 7: Report

The terms settled and where each landed, the ADRs written, and anything still ambiguous that the user has to decide before the code can. Then name what runs next: `/task_plan <issue>` when the vocabulary was blocking a plan, `/update_docs` when this pass turned up docs that now contradict the settled term.

## Reference
- Glossary: `docs/system/vocabulary.md` — one meaning per term, `_Avoid_` list beside it
- Decisions: `docs/adr/NNNN-<slug>.md`, four digits, one per file, indexed in `.llm/README.md`
- Conventions, one per file: `docs/rules/` + `docs/rules/INDEX.md`. Never restated here
- Model reference (tables, columns, associations): `docs/system/models.md`
- The three-part ADR test is Step 4, and it is the only place it lives: `/update_docs` points here rather than restating it
- Deep doc pass across the whole tree: `/update_docs`. Design interview before a gate: `/grill`
