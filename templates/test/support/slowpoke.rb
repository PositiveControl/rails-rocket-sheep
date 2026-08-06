# frozen_string_literal: true

# Slowpoke — flags tests slower than a threshold and prints a sorted report
# after the run. Zero dependencies, two `Process.clock_gettime` calls per test.
#
# The report only prints when something is actually slow, so this is safe to
# leave on for every run. Nothing to remember, nothing to opt into.
#
# Tune it with environment variables — no code change needed:
#
#   SLOWPOKE_THRESHOLD=1.0   bin/test   # seconds; default 0.5
#   SLOWPOKE_MAX_RESULTS=10  bin/test   # show only the worst N; 0 = all
#   SLOWPOKE_HISTORY=tmp/slowpoke.json bin/test   # also write JSON
#   SLOWPOKE_CI=true         bin/test   # exit 1 if any test is slow
#
# `SLOWPOKE_CI=true` fails the build on the first slow test, so turn it on only
# once the suite is actually under the threshold. Otherwise it's a red build
# that teaches people to ignore red builds.
#
# Rails parallelises by forking and each fork carries its own after-run hook, so
# a parallel run can print the report more than once. `PARALLEL_WORKERS=1
# bin/test` gives a single clean report — bin/test already forces that on macOS.
require "slowpoke/integrations/minitest"

Slowpoke.configure do |config|
  # Threshold, max_results, ci, and history_path already read their environment
  # variables in Slowpoke's own defaults. Override them here when a project
  # wants a different baseline than 500ms.
  #
  # config.threshold = 1.0
  # config.max_results = 10

  # System tests are slow by nature — a browser boot dwarfs the threshold. Raise
  # it when the report is all Capybara and no signal.
  config.color = $stdout.tty?
end
