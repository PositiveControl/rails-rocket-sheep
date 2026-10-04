# Workflow usage

What an autopilot step costs (dollars, minutes, turns, tokens, context, subagents),
recorded for every step the driver runs, so a change to a command can be judged by
numbers rather than by feel. It also records the cache settings those numbers
depend on.

What has been changed on the strength of these numbers, and the measured effect:
[`workflow-optimizations.md`](workflow-optimizations.md). To judge your own first
autopilot feature the same way, fill in
[`autopilot-report-template.md`](../qa/autopilot-report-template.md).

```bash
bin/autopilot <slug> --usage     # per command: cost, minutes, cache use, turns, context at the end
```

## Autopilot step rows

Each step attempt in the driver's state file records:
- `usd`;
- `seconds` (wall);
- `api_seconds` (model time; the rest is tools);
- `turns`;
- `tokens` (main conversation, by kind);
- `context_end` (the context at the last call);
- `models` (per-model cost and tokens, subagents included, from `modelUsage`);
- `subagents` (spawned);
- `denials` (permission denials, each a wasted turn);
- `variant`, on resolver rows only.

`usage` in a `claude -p` result covers only the main conversation. On one measured
`/implement` it was about 8% short, so `models` is where the full cost is.

## Reading `--usage`

One row per command (resolver rows split by `variant`), then a total:

| Column | Meaning |
|---|---|
| runs | step attempts |
| usd / avg usd | exact, from each `claude -p` result: total, and per run |
| avg min | wall minutes per run |
| hit | cache reads over every input token |
| read | cache reads; a large `read` per run is a large context re-sent each turn |
| write 5m / write 1h | cache writes, by TTL. `claude -p` writes at 1h, subagents at 5m |
| turns | agent turns |
| ctx end | the main conversation's context at its last call |
| agents | subagents started |
| denied | permission denials |

A **low hit** is a cold start: the step paid to write a context it then barely
reused. A **high hit with a large context at the end** is the opposite: a long
context, cheap per token but re-read on every turn. Resuming a long session does
this, which is why the resolver starts fresh by default (`autopilot.md`, *The
driver*).

## Cache TTL

`.claude/settings.json` sets `promptCacheTtl: "1h"` for the main conversation,
manual and autopilot alike.
- **On a subscription,** 1h is already the default within plan usage. Claude Code
  drops to 5m once usage goes past the plan into usage credits, which is exactly
  when a step or a long `bin/test` turn can least afford a rebuild.
- **With an API key,** the default is 5m, and this setting makes it 1h.

Subagents stay at the 5m default (`subagentPromptCacheTtl` unset). Measured in the
app this was ported from: 1,252 call gaps across 51 subagent transcripts, none over
5 minutes (the longest was 84s), so a 1h write price would buy nothing. Re-check
with the same measure before changing it. Reference:
[prompt caching](https://code.claude.com/docs/en/prompt-caching#cache-lifetime).

## Limits

- **Autopilot only.** Manual sessions record no per-command cost. Claude Code writes
  only an occasional session total.
- **The `claude -p` result format is Claude Code's.** The driver's tests pin the
  fields it reads. If a CLI update renames one, the column goes empty rather than
  wrong, and the tests are the place to fix it.
