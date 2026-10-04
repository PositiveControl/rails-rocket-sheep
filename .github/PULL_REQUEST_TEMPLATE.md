## Summary

<!-- 1–3 bullets: what changed and why. Drawn from the task file's goal and approach. -->

-

## Changes

<!-- Brief description of each file or area changed. -->

-

<!--
CLOSING LINE — depends on your tracker tier (see WORKFLOW.md §2):

  github-projects · labels   Add the line below. It closes the issue on merge,
                             and under github-projects the board's "item closed"
                             workflow then sets Done.

      Closes #<issue>

  beads                      Omit it. There is no GitHub issue to close, and a
                             stray "Closes #" would close an unrelated issue that
                             happens to share the number. /pick reconciles the
                             bead once this PR merges.

  slice of a feature branch  Omit it on every tier. GitHub closes issues only on
                             a merge to the default branch; the feature PR carries
                             one line per landed slice (WORKFLOW.md, Feature
                             branches). Write "Slice of feature/<slug>" instead.

/pr_submit handles this automatically. This note is for PRs opened by hand.
-->

## Test plan

- [ ] CI pipeline passes
- [ ] <!-- specific scenarios from the issue's acceptance criteria -->

## Checklist

- [ ] `bin/test` passes locally
- [ ] `bin/rubocop` and `bin/brakeman` are clean
- [ ] Docs updated, or no doc change needed — **no `Status: Draft` placeholder left behind** (a slice PR leaves the feature's placeholders for the feature PR)
- [ ] Added lines are within the 200–1,500 target, or the split is explained above
