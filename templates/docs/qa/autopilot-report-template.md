# Autopilot report: <slug>

<!--
A template. Copy it to docs/qa/<date>-<slug>-autopilot-report.md after a
feature's first autopilot run, then fill it in from the commands under
*Reproducing these numbers*. Delete this comment and any section with nothing to
say. The point is to judge the workflow by numbers rather than by feel: what a
slice cost, where the time went, and whether the policy's answers were right.
What each figure means: docs/system/workflow-usage.md. What has already been
changed on the strength of figures like these: docs/system/workflow-optimizations.md.
-->

**Status:** <interim, as of <date>: #<n> has landed | complete>

This report covers one feature, `<slug>` (<one line on what it is>, slices
#<first>–#<last>), run by `bin/autopilot` from start to finish. Compare it with
<an earlier run, a run before a change to the workflow, or the same commands run
by hand>.

## Summary

| Measure | Before (<slices>) | After (<slices>) | Change |
|---|---|---|---|
| Cost per slice | | | |
| Cost per 1,000 added lines | | | |
| Resolver cost per slice | | | |
| Resolver share of slice cost | | | |
| Wall time per slice | | | |
| Wall time per 1,000 added lines | | | |
| Self-review passes per slice | | | |

**Reading it.**
- <Which change did most of the saving, and what did it cost elsewhere.>
- <Slice sizes. Per-1,000-line figures are the fairer comparison when PR sizes
  differ.>
- <How large the sample is.>

## Data

**Sources.**
- Driver state rows: `tmp/autopilot/<slug>.json` in the autopilot worktree.
- PR sizes and reviews: GitHub.

**Eras.** <Which slices ran under which version of the workflow. A slice whose
row is incomplete, for example an interrupted step, is listed here and left out
of the averages.>

### Per slice

| Slice | PR | Added lines | Files | Cost | Resolver | Minutes | Notes |
|---|---|---|---|---|---|---|---|
| #<n> | #<pr> | | | | | | |

### Per step (`bin/autopilot <slug> --usage`)

| Step | Runs | Cost | Avg cost | Avg min | Hit | Ctx end |
|---|---|---|---|---|---|---|
| `/task_plan` | | | | | | |
| `/implement` | | | | | | |
| `/pr_submit` | | | | | | |
| `/pr_review` | | | | | | |
| `/pr_comment_resolver (fresh)` | | | | | | |

## Context

- **Largest contexts.** <Which steps end with the largest `ctx end`, and why.>
- **Manual compared with autopilot.** <The same commands run by hand, if you have
  numbers for them. Otherwise delete this item.>

## Cost

- **Where the money went.** <Share by step.>
- **What a change saved.** <Before and after, per slice and per 1,000 lines.>

## Speed

- <Wall time per 1,000 added lines, and which steps it went to.>
- **Lost time.**

  | Event | Slice | Time lost |
  |---|---|---|
  | <pause / halt / stop / CI rerun> | #<n> | |

## Accuracy

| Signal | Value | Notes |
|---|---|---|
| Halts | <n> in <n> slices | <each one's cause, and whether the policy or the driver changed> |
| Retries for an unmet expectation | | |
| CI reruns | | <flaky tests named, and whether each rerun went green> |
| Pass 2 needed | <n> of <n> | |
| Pass-1 verdict "request changes" | <n> of <n> | |
| Permission denials | | <which step, which tool> |

## Review passes

Each slice gets one local round of `/pr_review --local` inside `/implement` (L1)
and up to two self-review passes on the PR (P1, P2). P2 runs only when P1's
`**Findings:**` line counts a blocker or suggestion. A real bug means wrong runtime
behaviour, a data exposure, a crash or a race. The rest are tests, docs and style.

| Review | Reads | Real bugs found | Other findings |
|---|---|---|---|
| L1 | whole diff | | |
| P1 | whole diff | | |
| P2 | P1's fixes | | |

<Does P1 still find real bugs that L1 missed? In how many slices? That is the
evidence for keeping or cutting a review.>

## Reproducing these numbers

```bash
# per step, from the driver's state rows
bin/autopilot <slug> --usage

# per slice: cost, resolver cost, minutes (run in the autopilot worktree)
jq -r 'to_entries[] | .key as $i | [$i,
  ([.value.usage[]?.usd // 0] | add),
  ([.value.usage[]? | select(.step | startswith("/pr_comment_resolver")) | .usd // 0] | add),
  ([.value.usage[]?.seconds // 0] | add / 60 | round)] | @tsv' tmp/autopilot/<slug>.json

# PR size and self-review passes
gh pr view <pr> --json additions,changedFiles,reviews \
  --jq '[.additions, .changedFiles, (.reviews | map(select(.body | startswith("Self-review pass"))) | length)]'
```

## To finish

- [ ] Every slice is in *Per slice*, and *Per step* is refreshed after the last one.
- [ ] *Summary* compares eras with enough slices in each to mean something.
- [ ] Every halt, pause and CI rerun is under *Speed* and *Accuracy*.
- [ ] *Review passes* is tallied from the PR reviews and the autopilot log's rulings.
- [ ] What should change in the workflow, if anything, is filed as an issue.
