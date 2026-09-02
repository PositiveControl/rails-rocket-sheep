# Routing is two-tier, in both modes

## Context

`INDEX.md` routes by path: the file you are about to edit names the rules that apply.
The table is flat, so a path with many rules pointing at it names all of them, and
`app/views/**/*.slim` names ten. The worst lookup in the shipped corpus costs more
than seven thousand tokens — most of the corpus, to answer which part of it to read.

The adopted app hit this and restructured: a small always-read set per path, then
conditional tables — *editing a view, and you are also writing a form?* — with the
symptom table and the full annotated listing moved into a second file read only when
routing by path missed. Measured across eight representative flows, 99,478 tokens
became 49,898. The common path went from about 3,000 to about 1,180.

That work has not come back upstream. `templates/bin/doc-tokens` already skips a
`SYMPTOMS.md` by name, so half of it is anticipated here and the restructure itself
is not.

API mode makes this urgent rather than merely wasteful. `app/controllers/**` in an
API has `controllers`, `policy-objects`, `api-auth`, `error-envelope`,
`status-codes`, `pagination`, `rate-limiting`, `request-contracts` and
`serialization` pointing at it — the fan-out that made the view row expensive,
on the path an API app edits most.

## Decision

Routing is two files in both modes.

`INDEX.md` carries the always-read set per path plus the conditional tables, and is
the entry point. `SYMPTOMS.md` carries the symptom table and the full annotated
listing, and says at the top that it is for when routing by path did not answer.
`INDEX.md` points at it once.

Both modes, not just API mode. The HTML corpus is where the defect was measured, the
adopted app has a working reference implementation to port rather than a design to
invent, and two routing structures in one template would mean every future rule
landing in whichever index its author happened to be looking at.

`bin/lint-docs` extends its existing index check across both files: every rule is
routed from at least one of them, every link resolves, and no rule is listed in the
always-read set of a path whose rules it does not apply to.

## Consequences

Accepted:

- **A miss now costs two reads.** Routing by path and failing, then reading
  `SYMPTOMS.md`, is more expensive than the flat index was for that case. It is the
  trade the measurement endorses: the common path is much cheaper and the fallback
  is rarer than it is cheap.
- **Which tier a rule belongs in is a judgement, and it will be got wrong.** The
  always-read set is what applies to *any* edit in that path; everything else is
  conditional. Nothing checks that distinction, and a rule promoted into the
  always-read set out of enthusiasm re-creates the fan-out one row at a time.
- **Two files to keep in step, and `/update_docs` has to know.** A rule added to one
  and not the other is invisible until someone routes by the way it was missed.
  `bin/lint-docs` covers presence, not placement.
- **Every generated app's routing changes shape.** For an app updating through
  `bin/rocket-sheep-update` this is a rewrite of a file it may have edited, plus a
  new file. The adopted app has already done this by hand and will reconcile to
  roughly what it wrote.

Gained: the entry point stops costing three thousand tokens to answer a question
whose answer is two hundred, and the API corpus does not repeat the measurement to
learn it.

Measured on this corpus after the port, entry point 3,030 → 1,433:

| Flow | Before | After |
|---|---|---|
| Slim edit, everything the path row named | 7,070 | 2,983 |
| Slim edit, writing a form | 7,070 | 3,353 |
| Controller edit, path row as named | 6,330 | 3,023 |
| Controller edit, an index action | 6,330 | 3,383 |
| Model edit, path row as named | 5,410 | 2,373 |
| **Five flows summed** | **32,210** | **15,115** |

Fifty-four percent, against the roughly fifty the adopted app measured on its own
eight flows. `SYMPTOMS.md` costs ~2,280 when routing by path misses.

## Revisit when

A third tier is proposed. That is the point to check whether the conditional tables
have grown into the thing they replaced, rather than adding a level below them.
