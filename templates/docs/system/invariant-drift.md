# Invariant drift — a field guide

A domain rule that must hold across several code paths will hold on the paths whose
authors knew about it. Rails gives you many places to write the same state and one
place to notice you didn't.

This is the *why* behind several rules in [`../rules/INDEX.md`](../rules/INDEX.md) —
[invariants](../rules/invariants.md), the invariant-tests section of
[testing](../rules/testing.md), the status nuances in
[optional-patterns](../rules/optional-patterns.md), and
[design-docs](../rules/design-docs.md) — plus the review checks in
`.claude/commands/pr_review.md` and `rails_code_review.md`. Those say what to do; this
says how to recognize the failure and why the rule is shaped the way it is.

Generalized from a post-mortem: three services packed items into outbound shipments,
two of them moved the item's status, one didn't. The rule had been written down three
times — in a commit message, a code comment, and a design doc — and enforced zero
times. Six weeks later a fourth service inherited the assumption and built on top of it.

## The shape of the failure

This class of bug has a consistent life cycle. Every stage looks correct in review,
because at every stage the diff *is* correct within its own scope.

1. **A path ships without the rule**, because the rule wasn't part of the feature. The
   ticket describes a user-visible outcome; the record it creates has implications
   nobody framed as in-scope.
2. **Someone finds the bug on a sibling path** and fixes it there. Their commit message
   states the rule in general terms — a claim about the system — and their diff makes it
   true in one file.
3. **Later paths get it right by imitation**, citing the fix as precedent. Correctness
   propagates forward for free. Nothing propagates backward, because that requires
   someone to choose to.
4. **New code inherits the broken assumption.** A downstream feature reads the state the
   working paths produce and gates on it. Now the original omission has a dependent, and
   the fix has a blast radius.

## Group A — Where invariants live

A rule spread across call sites is a rule with no owner.

### An invariant enforced at call sites is enforced nowhere

If a rule must hold whenever some record is created, put it on that record's life cycle,
not in each service that creates it. Three call sites become four next quarter, and the
newest author copies whichever sibling they happened to read first.

- **Tell** — the same state write appears in more than one service. Sharper tell: the
  same rule restated in two services' comments, in each author's own words.
  ```sh
  git grep -n 'status: "awaiting_shipment"\|awaiting_shipment!'
  ```
- **Fix** — one chokepoint: an `after_create` on the join model every path writes (one
  that touches only its own record — see [callbacks](../rules/callbacks.md)), a single
  service all paths route through (see [write-path](../rules/write-path.md)), or a
  database constraint where the rule is genuinely structural. Then delete the
  duplicates, so there is one place left to be wrong.

### Invariant tests belong to the invariant, not to the service

A test named after a general rule, living in one service's test file, cannot fail when a
sibling service breaks that rule. Two authors will each write their own copy, and the path
that predates both will have none.

- **Tell** — a test name that states a rule about the domain ("… is not listable",
  "… cannot be double-charged") inside a file named after a single class.
- **Fix** — one test that enumerates every entry point and asserts the same properties for
  each. Derive the enumeration from the code where you can — iterate subclasses, a
  [registry](../rules/registries.md)'s `all`, the association's writers — so a new path
  fails by omission instead of being silently uncovered.

### When one real thing becomes two rows, name the mapping on day one

Ownership transfer, versioning, soft-delete-and-recreate, STI copies: any duplication
means every later feature re-derives which row carries the status, which carries the
association, and which the rest of the system points at. Logic that gets re-derived gets
re-derived wrongly.

- **Tell** — the same `where(source_x_id: …)` shape in more than one file.
  ```sh
  git grep -ln "source_.*_id\|original_.*_id\|predecessor_id" -- app
  ```
- **Fix** — one named method on the model, and every consumer calls it. Write it when you
  introduce the duplication, not when the fifth consumer appears.

### A guard that reads a state nothing writes protects nothing

A `before_action` or view conditional keyed to a status value is invisible when no path
produces that value on the records it guards. It survives review indefinitely because it
reads correctly.

- **Tell** — for each guard on a state value, find the writer. If the only writers sit in a
  different flow than the one the guard protects, the guard is decoration.
- **Fix** — every guard gets a test that constructs the blocked state and asserts the block.
  If you cannot construct that state, either the guard or the writer is wrong — both
  findings are worth having.

## Group B — Where side effects attach

Rails makes the wrong moment as easy to reach as the right one.

### Record creation usually means intent, not occurrence

An `after_create` costs one line, so consequences get attached to the moment a row appears
rather than the moment the world changes. A row saying "this will ship" is written when the
customer pays; the carton is packed days later, by someone else, and nothing records that.

- **Tell** — for each `after_create` or `after_commit on: :create` doing domain work, ask
  what real-world event that `INSERT` corresponds to. If the honest answer is "somebody
  asked for it", any consequence about physical reality is premature.
- **Fix** — split intent from occurrence and attach each write to its own signal. Where no
  event records the real occurrence, use the nearest human-triggered signal, name it a
  proxy in a comment, and say what should replace it. A proxy you have labelled is a
  decision; an unlabelled one is a bug in waiting.

### A guarded line beside an unguarded line is a bug or a comment

When a method or loop conditions one write and not the next, the two disagree about what is
true. Either one of them is wrong, or the asymmetry is deliberate and deserves a sentence
explaining it.

- **Tell** — read every `if` inside a loop body and ask whether the statements after it
  should share the condition. Cleanup calls beside conditional business logic are the common
  case — and the destructive half is usually the unguarded one.
- **Fix** — state the condition once and apply it to every write that depends on it, or
  record why they differ.

### Gate on the fact you mean, not on something that correlates with it

Conditions written against a status usually mean something else: "is this the buyer's copy",
"do we still hold this", "has this been paid for". The status correlates today and stops
correlating the moment a new flow produces a different one.

- **Tell** — a condition whose comment explains a different concept than the code checks.
  That gap is where the next bug lands.
- **Fix** — test the fact directly: ownership, association presence, a timestamp. Keep the
  status check only when status is genuinely the thing you mean.

## Group C — Status columns

A string column with generated predicates buys convenience and sells you every guarantee.

### A status that means different things in two directions is two concepts

Reusing one value across opposing flows makes every downstream rule ambiguous. Constants
built on it — editability, visibility, search scopes — then apply the wrong half to half the
records, and each one reads as correct in isolation.

- **Tell** — enumerate a value's consumers. If two of them assume opposite things about the
  same value, it is overloaded.
- **Fix** — split the concept. When splitting is too invasive to justify, make every consumer
  of the overloaded value also test direction, and add a test per consumer — the tests are
  what stop the next author reading it as unambiguous.

### Declared states need declared transitions

A status column with generated predicates gives you no transition enforcement and no
exhaustiveness checking. The house pattern for this — a validated enum plus a
`transition_to!` chokepoint — is in [optional-patterns](../rules/optional-patterns.md);
what follows is how to notice you need it.

- **Tell** — a list of statuses with no transition map anywhere near it. Then, per value: is
  there a writer, and is there a path from creation to it?
- **Fix** — declare the transitions: a state machine, or a validated table of legal
  `was → is` pairs. Even without one, the cheap version pays: a test per flow asserting the
  state it ends in.

### Terminal states need something that reaches them

"Nothing transitions out of this" gets documented. "Something transitions into it" usually
doesn't get verified, and a terminal state no flow reaches is a flow that never finishes.

- **Tell** — count rows per declared state against real data. Zero in a state you shipped
  months ago is a finding, not a quiet success.
  ```ruby
  Model.group(:status).count
  # any declared value missing from these keys?
  ```
- **Fix** — a test per terminal state that drives a full flow into it. Where the flow spans a
  queue or an external callback, assert the state after simulating that callback rather than
  trusting the code path exists.

## Group D — Review and process signals

Places where the information was already in front of somebody.

### If your commit message states a rule, the diff must cover the rule

The scope of the prose and the scope of the change should match. "We only list items we
hold" is a claim about the system; a one-file diff makes it true in one file. Every future
reader of that message believes it holds everywhere, and reasons from it.

- **Tell** — any commit or PR body containing *we always*, *we never*, *we only*. Treat each
  as a repository-wide assertion and go check it.
- **Fix** — before merging, prove the rule holds everywhere or write the exception into the
  message. The grep is a minute; this is the single cheapest intervention in this document.

### Precedent propagates forward, so audit backward

A fix that later code cites as precedent keeps spreading correctly. The paths written
*before* it never receive it. Copying forward is free; retrofitting backward requires
somebody to decide to.

- **Tell** — a comment naming another class as precedent. Every one is an implicit claim that
  a shared rule exists, so go find the paths older than the comment.
  ```sh
  git grep -n "precedent\|same as\|mirrors\|per the pattern in" -- app
  ```
- **Fix** — when you cite precedent, list the siblings you checked. When you establish one,
  grep for the ones that predate you and say what you found.

### The ticket's framing sets the review's attention

A change described by its user-visible effect gets reviewed for that effect. A record created
"so the invoice reads Paid" is reviewed as an invoice change, and nobody asks what the new row
implies for the models it references.

- **Tell** — a PR whose title names a UI outcome while its diff creates or transitions domain
  records.
- **Fix** — for any change that creates or transitions a record, state in the PR what happens
  to each model that record touches. "Nothing" is a fine answer, and it is one a reviewer can
  now challenge.

### Repeat backfills mean writes are scattered

One backfill is a migration. Two in the same subsystem means state is being derived in more
places than it is written, and the tasks are patching the gap between them.

- **Tell** — group your backfill tasks by subsystem and look for the cluster.
  ```sh
  ls lib/tasks/backfill_* db/data_migrations 2>/dev/null
  ```
- **Fix** — treat the second one as a signal to find the chokepoint, not merely as a task to
  write. Writing it without asking guarantees a third.

## The one question

Every rule here is a way of asking the same question earlier: *where else does this have to
be true?* When a commit message states a rule, grep for it before merging. Move each
cross-path invariant into one test that enumerates the paths. Count your backfill tasks by
subsystem, and read the cluster as a design finding.
