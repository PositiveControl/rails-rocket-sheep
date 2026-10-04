# Foo — autopilot log

**Design:** [Foo](2026-10-02-foo-design.md) · **Feature PR:** #53
**Run:** <started> → <finished> · **Usage:** <driver total>

## Read this first

<!-- Regenerated at finalize. Every `costly` and `one-way` entry, every drop,
every issue filed, every `opinion`, every HALT, ranked by how hard each is to
reverse. -->

## Policy accepted at G1

**Changes from the defaults:** none

| Gate id | Where it comes up | Answer |
|---|---|---|
| `choice` | Anywhere | Make it, and log it with the alternative |

**Halt list:** as in docs/system/autopilot-steps.md. Reversible: one-way is a schema change.

## Slices

<!-- One section per slice, in merge order:

### #<issue> — <title> (PR #<n>, merged <SHA>)

#### Decisions
<entries>

#### Dropped review findings
- <claim> — probe: <command and output> — `file:line`
-->

### #47 — Realtime via ActionCable (PR #67, merged 1a2b3c4)

| Added | Files | Review rounds | Fixed | Dropped | Wall time | Usage |
|---|---|---|---|---|---|---|
| 900 | 12 | 2 | 4 | 1 | 2h 10m | $14.20 |

#### Decisions

#### D47-1 · `G2` · Approve the plan as written?
- **Options:** approve · halt
- **Chose:** approve, because it is within the bound
- **Trade-off:** none
- **Reversible:** cheap
- **Evidence:** .llm/tasks/47_realtime.md

#### D47-2 · `choice` · Reconnect backoff: fixed or exponential?
- **Options:** fixed 2s · exponential to 30s
- **Chose:** exponential, because a server restart would otherwise be stampeded
- **Trade-off:** a slower reconnect after a long outage
- **Reversible:** costly
- **Evidence:** abc1234

#### Dropped review findings
- Token in the cable URL — probe: `grep -n token app/channels` shows none — `app/channels/application_cable/connection.rb:12`

#### Issues filed
- #60 `/cart` exposes its item limit — found in the manual check

## QA — how to check the whole feature

## Open questions for the developer

## Halts and pauses

#### HALT · `comments` · a person commented on PR #67
- **Where:** /pr_comment_resolver on `feat/47/realtime` at 9f8e7d6
- **Needs:** an answer to the comment

## Metrics

| Slice | Step | Wall time | Usage | Retries | Pauses |
|---|---|---|---|---|---|
| #47 | `/task_plan 47` | 4m 0s | $1.10 | 0 | 0 |

#### D48-1 · `G2` · Approve the plan as written?
- **Options:** approve · halt
- **Chose:** approve
- **Trade-off:** none
- **Reversible:** cheap
- **Evidence:** .llm/tasks/48_top_down.md

#### D48-2 · `opinion` · Which format reads best on a phone?
- **Options:** top-down · isometric
- **Chose:** top-down, as a draft for the developer
- **Trade-off:** isometric looks better in screenshots
- **Reversible:** cheap
- **Evidence:** docs/plans/formats.md

#### D48-3 · `choice` · Add a `format` column to players?
- **Options:** column · local setting
- **Chose:** column, because it follows the player across devices
- **Trade-off:** a migration
- **Reversible:** one-way
- **Evidence:** db/migrate/2026_add_format.rb
