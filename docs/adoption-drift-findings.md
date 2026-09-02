# What the uCollect adoption did to the rule corpus

Evidence for the API rule set ([ADR 0009](../.agents/adr/0009-api-mode-is-a-generation-flag.md)).
Before writing conventions for a mode this template has never generated, it is worth
knowing what happened to the conventions it *has* shipped when they met a real
codebase.

One app has adopted the alignment layer: uCollect, a Rails 8 marketplace of roughly
160 models and 200 controllers. Its `CLAUDE.md` stamps the template commit it
adopted from, and at the time of measurement that commit was this repo's `HEAD`. So
none of what follows is the template moving on — every line of difference is a
choice someone made to fit a rule to an app. That is the only clean read of this
kind available, and it is available once.

## What survived contact

Measured on rule bodies with the `tokens:` line excluded, since that line changed
everywhere for an unrelated reason (see [Read costs](#read-costs)).

| Drift | Rules |
|---|---|
| Byte-identical | `callbacks` · `scopes` · `safe-migrations` · `n-plus-one` · `current-attributes` |
| One example swapped | `caching` · `query-objects` · `turbo-status` · `turbo-frames` · `slim-gotchas` · `accessibility` |
| Expanded, 13–47 lines | `exception-boundary` · `partials` · `optional-patterns` · `jobs` · `write-path` · `controllers` · `seeds` · `empty-states` · `forms-ui` · `stimulus` · `turbo-streams` · `audit-trail` · `pattern-budget` · `database-conventions` · `rate-limiting` · `view-code-placement` |
| Rewritten, 60–88 lines | `deletes` · `tailwind` · `service-objects` · `pagination` · `policy-objects` · `testing` |
| Deleted | `components` · `form-objects` · `registries` |

Three ADRs and one SOP were deleted with them, each for the same reason the rules
were: they record a decision the app never made.

**The predictor is not the layer. It is whether the rule names a mechanism.**

The five that survived verbatim state a property of Rails itself — a callback that
writes another record, a class method that should have been a scope, a migration
against a live table, a query per row, `Current.user`. There is nothing in them for
an app to disagree with.

Every rule that named a gem, a base class, or a directory was rewritten:

| Rule said | App had |
|---|---|
| Discard, `.kept` | hand-rolled `deleted_at` on a few tables, no gem |
| Pagy, wired into `ApplicationController` | manual `limit`/`offset` and a shared pagination partial |
| `app/policies/`, a policy object per question | Petergate `access` plus a scoped lookup |
| Minitest fixtures | FactoryBot, with fixtures still loading alongside |
| Rails 8 `rate_limit` | Rack::Attack middleware |
| `ApplicationService.call(user:)` returning `result.value` | plain classes, per-class `Result`, `result.data` |

That is a sharper transferability test than "is this rule layer-agnostic", and it can
be applied to a rule before it is written rather than after it is adopted.

## The six edits contact forces

Every adapted rule is some combination of these. They are worth naming because they
are the shape a rule file has to accommodate, and one of them has nowhere to go.

| Edit | What it is |
|---|---|
| Current-state block | A paragraph stating the gap between the rule and the codebase, and which half is still enforceable in review |
| Mechanism substitution | The rule keeps its id and its job; the body is replaced |
| Inversion to prohibition | "Here is how to use X" becomes "X does not exist here, do not add it without an ADR" |
| Census anchoring | A count of the thing the rule governs, so a reader knows whether they are in a greenfield or a thicket |
| Example repair | The template's own base-class calls rewritten to whatever the app actually does |
| Cross-reference rewiring | `see_also` and `applies_to` repointed off deleted rules; ADR links dropped |

The first one is the finding. A rule file's shape is title, principle, example, cost.
Eight adapted rules needed a fifth part — *where this app actually is* — and since
the format has no slot for it, each one improvised a position and a voice. It reads
well in `controllers`, which states plainly that the codebase does not obey the rule
yet and that this makes it a target for new code rather than an advisory note. It
reads as an apology in others.

A generated app does not need this block: the mechanisms the rules describe are the
ones `template.rb` just installed. An *adopted* app needs it in every mechanism rule.
Since `adopt.rb` is a supported path, the format should decide where the block goes
before a second corpus improvises it again.

## Read costs

The `tokens:` figures moved on every file, which looked at first like every rule
doubling in size. It was not. The figures were under-declared upstream and the
adoption regenerated them; the fix then landed here as `templates/bin/doc-tokens`.

| | Rules | Declared | Actual | Error |
|---|---|---|---|---|
| Template, at the adopted commit | 38 | 12,850 | ~18,410 | 30% under |
| Template, now | 38 | 18,320 | ~18,410 | under 1% |
| The adopted app | 35 | 18,720 | ~18,810 | under 1% |
<!-- lint-docs:ignore — the 35 and the second 38 above count another repo's corpus and this repo's at an older commit -->

Real content growth is about 20% on the median rule that changed, and the corpus
total barely moved — three deletions paid for the rewrites. Per rule the adopted
corpus averages 535 tokens against 482 here, so **describing a real app costs about
a tenth more per rule than describing a greenfield one**, not double.

Churn and growth are also independent, which is worth knowing before reading a diff
stat as a severity signal. `deletes` churned 60 lines at 6% growth — a replacement.
`database-conventions` churned 43 lines and got 18% *smaller*, because one of its two
database halves stopped applying. `pagination` grew 134%.

## Routing was restructured, and that has not come back upstream

The largest single change was not to a rule. The template's index routes by path,
and its `app/views/**/*.slim` row named ten rules; the worst-case lookup cost more
than seven thousand tokens, which is most of a corpus to answer one question.

The adoption split it in two: a small always-read set per path, then conditional
tables — *editing a view, and you are also writing a form?* — with the symptom table
and the full annotated list moved into a second file read only when routing by path
missed.

| Entry point | Template | Adopted |
|---|---|---|
| Route by path, the common case | ~3,000 | ~1,180 |
| Route by symptom, the fallback | same file | ~2,290, on a miss |

Across eight representative flows the adoption measured 99,478 tokens before and
49,898 after. `bin/doc-tokens` already skips a `SYMPTOMS.md` by name, so the second
file is half-anticipated here; the routing change itself is not.

This matters for the API corpus immediately. An `app/controllers/**` row in API mode
has `controllers`, `policy-objects`, `api-auth`, `error-envelope`, `status-codes`,
`pagination`, `rate-limiting`, `request-contracts` and `serialization` pointing at
it — the same fan-out that made the view row expensive. Two-tier routing is cheaper
to build before the rules than to retrofit after them.

## What this changes for the API corpus

**The transfer tier holds for generation.** Five rules verified byte-identical and
one near it. Of the rules that broke the prediction, all but one broke because the
app's mechanisms differ from the template's — which is not the situation a
`rails new --api` is in. `registries` was deleted only because the app has no
`app/lib/`; API mode keeps that directory, so the rule stays.

**It does not hold for adoption.** An existing JSON app taking the API corpus
through `adopt.rb` will rewrite every mechanism rule in it, exactly as uCollect did.
That is the second audience for the corpus, and the current-state block is how it
gets served.

**The deliverable gains a file.** Two-tier routing means the corpus ships an index
and a symptom file, not one index.

Three things to settle before the first API rule is written:

1. Where the current-state block lives — prose convention, or a frontmatter field
   that `bin/lint-docs` can check for presence in mechanism rules.
2. Whether two-tier routing lands for both modes or only the new one. Both is one
   change to `INDEX.md`; only the new mode is two indexes to maintain.
3. Whether a superseded decision is deleted or annotated. ADR 0009 says a decision
   that does not apply in a mode keeps its number and gains a mode line; this
   adoption deleted three outright. Generation and adoption may honestly want
   different answers, but the template should say which is which.

## Method

Rule bodies compared between this repo at the commit the app's `CLAUDE.md` stamps
and the app's own `docs/rules/`. Drift counted as changed lines with the `tokens:`
line filtered out. Read costs estimated at chars/3.8, the constant
`templates/bin/doc-tokens` uses, so the figures here and the frontmatter figures are
comparable. The app's own account of its deviations — ten numbered divergences, the
deletions, and the token pass — is in its `docs/plans/rocket-sheep-adoption-followups.md`.
