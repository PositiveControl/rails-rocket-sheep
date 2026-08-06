# Find slow tests

**Status:** Complete

Slowpoke reports tests slower than a threshold after every run. This is how to
read that report and act on it.

---

## The default

Nothing to run. `bin/test` already loads Slowpoke via
`test/support/slowpoke.rb`, and the report prints only when something crosses
the threshold (500ms by default):

```
🐌 Slowpoke found 3 slow tests (>500ms):

  1203.4ms  UserTest#test_sends_welcome_email
            test/models/user_test.rb:42
  872.1ms   OrderTest#test_calculates_tax_for_international
            test/models/order_test.rb:18
  511.3ms   AuthTest#test_locks_after_failed_attempts
            test/integration/auth_test.rb:7
```

Anything over twice the threshold prints red; the rest yellow. A clean run
prints nothing at all.

---

## Tuning a single run

All four knobs are environment variables — no code change, no commit:

| Variable | Default | Does |
|---|---|---|
| `SLOWPOKE_THRESHOLD` | `0.5` | Seconds. Below this, a test is not reported. |
| `SLOWPOKE_MAX_RESULTS` | `0` | Show only the worst N. `0` means all. |
| `SLOWPOKE_HISTORY` | unset | Also write the run to a JSON file. |
| `SLOWPOKE_CI` | `false` | Exit 1 when any test is slow. |

```bash
# What's slower than two seconds?
SLOWPOKE_THRESHOLD=2.0 bin/test

# Just the ten worst offenders in the model tests
SLOWPOKE_THRESHOLD=0.3 SLOWPOKE_MAX_RESULTS=10 bin/test test/models/

# Capture a run for comparison
SLOWPOKE_HISTORY=tmp/slowpoke.json bin/test
```

The JSON has a timestamp, the threshold used, a count, and each test's name,
location, and duration in milliseconds — enough to diff two runs or chart the
suite over time.

---

## Changing the project default

Edit `test/support/slowpoke.rb`:

```ruby
Slowpoke.configure do |config|
  config.threshold = 1.0     # this suite's floor
  config.max_results = 15
end
```

Raise the threshold when the report is all Capybara. A browser boot dwarfs
500ms, so system tests will fill the list and hide the unit tests that are slow
for a fixable reason. Raising it is better than deleting the report.

---

## Parallel workers

Rails parallelises the suite by forking, and each fork carries its own copy of
the after-run hook. If the report appears more than once, or looks partial, run
the suite in a single process:

```bash
PARALLEL_WORKERS=1 bin/test
```

`bin/test` already forces this on macOS, where forked workers cause unrelated
crashes. On Linux and CI you may need the flag explicitly to get one clean
report.

---

## Reading the result

The report tells you *which* tests are slow. Why, in rough order of how often
it's the answer:

| Symptom | Usual cause | Fix |
|---|---|---|
| A model test over 500ms | Records created in `setup` that the test doesn't use | Build only what the assertion touches; use fixtures |
| Whole test files uniformly slow | Expensive `setup` running per test | Move invariant setup to a fixture or a `setup do` that memoizes |
| One test far slower than its neighbours | Real HTTP request escaping WebMock | Record a VCR cassette — see the VCR config in `test/support/vcr.rb` |
| Integration tests slow across the board | Full-stack rendering plus a real database | Expected. Raise the threshold rather than chasing it |
| A test whose duration varies run to run | `sleep`, or a Capybara wait timing out | Replace `sleep` with an explicit wait on a condition |

A slow test is usually a test doing setup work it doesn't need. Look at what it
creates before you look at what it asserts.

---

## Enforcing a ceiling in CI

Once the suite is genuinely under the threshold, make it stay there:

```yaml
# .github/workflows/ci.yml
- name: Run tests
  env:
    SLOWPOKE_CI: "true"
    SLOWPOKE_THRESHOLD: "1.0"
  run: bin/test
```

`SLOWPOKE_CI=true` exits 1 the moment any test crosses the line.

**Turn this on last.** A build that goes red on a suite nobody has cleaned up
yet teaches the team to ignore red builds, which costs more than slow tests do.
Get under the threshold first, then lock it.

---

## Related

- `test/support/slowpoke.rb` — the configuration this app ships
- `test/support/vcr.rb` — the usual fix for a single wildly slow test
- [github.com/PositiveControl/slowpoke](https://github.com/PositiveControl/slowpoke)
