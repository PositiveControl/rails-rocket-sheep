# frozen_string_literal: true

require "minitest/autorun"
require "erb"
require "yaml"
require "active_support/core_ext/object/blank" # database.yml's production block calls present?
require "json"
require "tmpdir"
require "fileutils"
require "stringio"
require "open3"

# bin/autopilot runs a feature in its own worktree, beside the developer's
# checkout. Plain Minitest, like test/bin/flay_test.rb: nothing here boots
# Rails or touches a database, so it can run while the developer's own suite
# is using the shared test databases.

load File.expand_path("../../bin/autopilot", __dir__)

# Stands in for Autopilot::Shell. Each rule is [pattern, reply]; the newest
# matching rule wins, and a reply may be a lambda for answers that change
# between calls. Every call is recorded, so a test can say what never ran.
class FakeShell
  attr_reader :calls

  def initialize
    @rules = []
    @calls = []
  end

  def on(pattern, out = "", ok: true, timed_out: false, &block)
    @rules.unshift([ pattern, block || ->(_) { Autopilot::Shell::Result.new(out, ok, timed_out) } ])
    self
  end

  def run(*cmd, env: {}, chdir: nil, timeout: nil)
    line = cmd.join(" ")
    @calls << { line: line, env: env, chdir: chdir, timeout: timeout }
    rule = @rules.find { |pattern, _| pattern === line }
    rule ? rule[1].call(line) : Autopilot::Shell::Result.new("", true, false)
  end

  def spawn_background(cmd, env:, chdir:, log:)
    @calls << { line: "spawn #{cmd.join(' ')}", env: env, chdir: chdir, log: log }
    4242
  end

  def kill_group(pid) = @calls << { line: "kill_group #{pid}" }
  def alive?(pid) = @alive.to_a.include?(pid)
  def alive!(*pids) = @alive = pids

  def ran?(pattern) = @calls.any? { |call| pattern === call[:line] }
  def lines = @calls.map { |call| call[:line] }
end

module AutopilotFixtures
  # The example app every test runs against, as /workflow_setup records it:
  # acme/shop, branches under feat/, tier labels. A test of another tier swaps
  # the tracker in (#tier!).
  CONFIG = File.expand_path("fixtures/autopilot/workflow.config.md", __dir__)

  def before_setup
    super
    Autopilot.config = Autopilot::Config.read(CONFIG)
  end

  BOARD_IDS = { "PROJECT_NAME" => "Shop", "PROJECT_ID" => "PVT_1", "STATUS_FIELD_ID" => "PVTSSF_1",
                "STATUS_TODO" => "opt-todo", "STATUS_IN_PROGRESS" => "opt-doing", "STATUS_UP_FOR_REVIEW" => "opt-review",
                "STATUS_DONE" => "opt-done", "STATUS_BLOCKED" => "opt-blocked" }.freeze

  # The fixture's config on another tier; under github-projects, with the
  # board IDs /workflow_setup would have recorded.
  def tier!(tracker)
    text = File.read(CONFIG).sub("| `TRACKER` | `labels` |", "| `TRACKER` | `#{tracker}` |")
    BOARD_IDS.each { |key, value| text.sub!("| `#{key}` | `n/a` |", "| `#{key}` | `#{value}` |") } if tracker == "github-projects"
    Autopilot.config = Autopilot::Config.new(text.scan(Autopilot::Config::ROW).to_h)
  end

  # `gh issue view --json body,projectItems,state`: the issue's card on the
  # app's board, and one on another board that must not count.
  def board_issue_json(deps, option:, name: nil)
    items = [ { "status" => { "optionId" => "opt-x", "name" => "Done" }, "title" => "Other board" },
              { "status" => { "optionId" => option, "name" => name }.compact, "title" => "Shop" } ]
    body = "## Goal\nx\n\n## Dependencies\n#{deps}\n"
    JSON.generate("body" => body, "projectItems" => items, "state" => "OPEN")
  end

  # The graphql lookup that finds the issue's item on the app's board.
  def board_items_json(item)
    nodes = [ { "id" => "PVTI_other", "project" => { "id" => "PVT_9" } }, { "id" => item, "project" => { "id" => "PVT_1" } } ]
    JSON.generate("data" => { "repository" => { "issue" => { "projectItems" => { "nodes" => nodes } } } })
  end

  # `bd show <hash> --json`, as bd 0.61 prints it: an array of one. Real ids
  # carry the database's prefix; a slice names them `bd-<hash>`.
  def bead_json(hash, status:, labels: [], blocked_by: [])
    deps = blocked_by.map { |dep| { "id" => "shop-#{dep}", "dependency_type" => "blocks" } } +
           [ { "id" => "shop-epic1", "dependency_type" => "parent-child" } ]
    JSON.generate([ { "id" => "shop-#{hash}", "title" => "Slice #{hash}", "status" => status, "labels" => labels, "dependencies" => deps } ])
  end

  BEAD_SLICES = <<~MD
    ## Slices
    - [x] bd-a1 — Cart store (PR #57)
    - [ ] bd-b2 — Checkout
    - [ ] bd-c3 — Receipts
  MD

  # Feature PR #53's Slices list, verbatim as of 2026-10-02: #47 landed, #60
  # was inserted mid-list.
  SLICES = <<~MD
    ## Slices
    - [x] #44 — Scaffold the storefront, alignment layer, gates, CI (PR #54)
    - [x] #45 — Sign-in and API core (PR #57)
    - [x] #56 — Login screen and signed-in status bar (split from #45) (PR #58)
    - [x] #46 — Cart store, shared header, checkout writes (PR #59)
    - [x] #47 — Realtime via ActionCable with bearer auth (PR #67)
    - [ ] #60 — `/cart` exposes its item limit; the header shows a full cart (found in #47's manual check)
    - [ ] #48 — Top-down 2D format and live format switcher
    - [ ] #49 — Isometric 2D format
    - [ ] #50 — Orthographic 3D format and order replay
    - [ ] #51 — Format comparison write-up

    Closes #44
  MD

  def issue_json(deps, labels: [ "status:todo" ])
    body = "Feature branch: feature/foo\n\n## Goal\nx\n\n## Dependencies\n#{deps}\n"
    JSON.generate("body" => body, "labels" => labels.map { |name| { "name" => name } }, "state" => "OPEN")
  end

  def design_repo(autopilot_line: "**Autopilot:** on — log: docs/plans/2026-10-02-foo-autopilot.md")
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, "docs/plans"))
    File.write(File.join(dir, "docs/plans/2026-10-02-foo-design.md"),
               "# Foo\n\n**Feature branch:** feature/foo\n\n#{autopilot_line}\n\n**Status:** Approved at G1\n")
    File.write(File.join(dir, "docs/plans/2026-10-02-foobar-design.md"),
               "# Foobar\n\n**Feature branch:** feature/foobar\n\n**Autopilot:** on\n")
    dir
  end
end

# .claude/workflow.config.md, read the way /workflow_setup writes it.
class AutopilotConfigTest < Minitest::Test
  include AutopilotFixtures

  def config(text) = Autopilot::Config.new(text.scan(Autopilot::Config::ROW).to_h)

  def test_reads_the_values_the_driver_needs_from_the_fixture
    config = Autopilot::Config.read(CONFIG)

    assert_equal "acme/shop", config.repo
    assert_equal "feat", config.branch_prefix
    assert_equal "labels", config.tracker
    assert_equal '^(docs|\.llm)/|\.md$', config["SUITE_SKIP_PATHS"], "a value may hold pipes"
    assert_empty config.problems
  end

  # The shape /workflow_setup wrote before the format was pinned: braced
  # tokens, and notes after the value. Re-running the wizard can keep it.
  def test_reads_a_record_in_the_older_shape
    config = config(<<~MD)
      | Token | Value |
      |---|---|
      | `{{TRACKER}}` | `labels` |
      | `{{GITHUB_ORG}}` | `acme` (personal account — GraphQL uses `user(login:)`) |
      | `{{GITHUB_REPO}}` | `shop` |
      | `{{BRANCH_PREFIX}}` | `feat` → `feat/<id>/<slug>` |
      | `{{PR_TITLE_PREFIX}}` | *(none — segment dropped)* |
    MD

    assert_equal "acme/shop", config.repo
    assert_equal "feat", config.branch_prefix
    assert_empty config.problems
  end

  def test_a_missing_file_names_every_value_it_needs
    problems = Autopilot::Config.read("/nonexistent/workflow.config.md").problems

    %w[TRACKER GITHUB_ORG GITHUB_REPO BRANCH_PREFIX].each do |key|
      assert problems.any? { |p| p.include?("`#{key}`") }, "#{key} not named: #{problems.inspect}"
    end
  end

  # Board IDs are n/a on the other tiers; under github-projects that is a
  # board the driver cannot move a card on.
  def test_github_projects_needs_every_board_id
    text = File.read(CONFIG).sub("`labels`", "`github-projects`")

    problems = config(text).problems
    assert(problems.any? { |p| p.include?("`STATUS_BLOCKED`") })
    assert(problems.any? { |p| p.include?("`PROJECT_ID`") })
    assert_empty config(text.gsub("`n/a`", "`X1`")).problems
  end

  def test_an_unknown_tier_is_named
    assert_match(/TRACKER is `jira`/, config(File.read(CONFIG).sub("`labels`", "`jira`")).problems.join)
  end
end

class AutopilotShellTest < Minitest::Test
  def test_runs_a_command_and_reports_success
    result = Autopilot::Shell.new.run("echo", "hi")

    assert result.ok
    assert_equal "hi\n", result.out
    refute result.timed_out
  end

  def test_reports_failure_with_output
    result = Autopilot::Shell.new.run("sh", "-c", "echo oops >&2; exit 3")

    refute result.ok
    assert_includes result.out, "oops"
  end

  # Ctrl-C lands in the driver; the step is in its own process group and
  # never sees it. The driver must take the step down, not wait for it.
  def test_an_interrupt_takes_the_step_s_whole_group_down
    handler = trap("INT", "DEFAULT")
    dir = Dir.mktmpdir
    pidfile = File.join(dir, "pid")
    runner = Thread.new do
      Autopilot::Shell.new.run("sh", "-c", "sleep 30 & echo $! > #{pidfile}; wait")
      :finished
    rescue Interrupt
      :interrupted
    end
    sleep 0.05 until File.exist?(pidfile) && !File.read(pidfile).empty?
    started = Time.now
    runner.raise(Interrupt)

    assert_equal :interrupted, runner.value
    assert_operator Time.now - started, :<, 10, "waited for the step instead of stopping it"
    grandchild = File.read(pidfile).to_i
    deadline = Time.now + 5 # an orphan is gone once launchd reaps it
    sleep 0.05 while Time.now < deadline && (Process.kill(0, grandchild) rescue false)
    assert_raises(Errno::ESRCH) { Process.kill(0, grandchild) }
    assert_equal "IGNORE", trap("INT", handler), "a second Ctrl-C would cut the cleanup short"
  ensure
    trap("INT", handler)
    FileUtils.remove_entry(dir)
  end

  # A step is a process tree (claude, and whatever it spawned). On timeout the
  # whole group goes, not just the parent.
  def test_timeout_kills_the_whole_process_group
    marker = File.join(Dir.mktmpdir, "child-alive")
    started = Time.now
    result = Autopilot::Shell.new.run("sh", "-c", "(sleep 2; touch #{marker}) & sleep 5", timeout: 0.3)

    assert result.timed_out
    refute result.ok
    assert_operator Time.now - started, :<, 2
    sleep 2.2
    refute File.exist?(marker), "the backgrounded child outlived the timeout"
  end
end

class AutopilotFeatureTest < Minitest::Test
  include AutopilotFixtures

  def setup
    @root = design_repo
    @shell = FakeShell.new
    @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => SLICES } ]))
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def feature = Autopilot::Feature.new("foo", shell: @shell, root: @root)

  def test_finds_its_design_doc_by_exact_branch
    assert_equal File.join(@root, "docs/plans/2026-10-02-foo-design.md"), feature.design_doc
  end

  def test_reads_consent_and_the_log_path
    assert feature.autopilot_on?
    assert_equal "docs/plans/2026-10-02-foo-autopilot.md", feature.log_path
  end

  def test_on_hold_is_not_consent
    root = design_repo(autopilot_line: "**Autopilot:** on hold until #47 lands")

    refute Autopilot::Feature.new("foo", shell: @shell, root: root).autopilot_on?
  ensure
    FileUtils.remove_entry(root)
  end

  def test_parses_the_slices_list_in_order
    slices = feature.slices

    assert_equal [ 44, 45, 56, 46, 47, 60, 48, 49, 50, 51 ], slices.map(&:issue)
    assert_equal [ 44, 45, 56, 46, 47 ], slices.select(&:done).map(&:issue)
  end

  def test_next_slice_is_the_first_open_one_whose_dependencies_are_ticked
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state", issue_json("#47 must merge first."))

    assert_equal 60, feature.next_slice.issue
  end

  def test_skips_a_slice_whose_dependency_is_still_open
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state", issue_json("#48 must merge first."))
    @shell.on("gh issue view 48 --repo acme/shop --json body,labels,state", issue_json("#46 must merge first."))

    assert_equal 48, feature.next_slice.issue
  end

  # A dependency outside the Slices list (another feature's issue) cannot be
  # ticked here, so it does not hold the slice back.
  def test_ignores_dependencies_outside_the_slices_list
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state", issue_json("#12 and #47 must merge first."))

    assert_equal 60, feature.next_slice.issue
  end

  def test_a_blocked_slice_is_reported_not_skipped_past
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state",
              issue_json("#47 must merge first.", labels: [ "status:blocked" ]))

    slice = feature.next_slice

    assert_equal 60, slice.issue
    assert slice.blocked
  end

  # GitHub renders [X] as ticked too.
  def test_an_uppercase_tick_counts_as_done
    @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => "- [X] #1 — a\n- [ ] #2 — b\n" } ]))

    assert_equal [ 1 ], feature.slices.select(&:done).map(&:issue)
  end

  def test_none_left_when_every_slice_is_ticked
    @shell.on(/gh pr list .*--head feature\/foo/,
              JSON.generate([ { "number" => 53, "body" => "## Slices\n- [x] #1 — a\n- [x] #2 — b\n" } ]))

    assert_nil feature.next_slice
  end

  def test_ticking_a_slice_marks_it_names_its_pr_and_adds_closes_after_the_last_one
    body = Autopilot::Feature.ticked(SLICES, 60, 71)

    assert_includes body, "- [x] #60 — `/cart` exposes its item limit; the header shows a full cart (found in #47's manual check) (PR #71)\n"
    assert_includes body, "- [ ] #48 — Top-down"
    assert_includes body, "Closes #44\nCloses #60\n"
    assert_equal body, Autopilot::Feature.ticked(body, 60, 71), "ticking twice changes nothing"
  end

  def test_ticking_does_not_touch_a_longer_issue_number
    body = Autopilot::Feature.ticked("## Slices\n- [ ] #600 — a\n- [ ] #60 — b\n\nFooter\n", 60, 71)

    assert_equal "## Slices\n- [ ] #600 — a\n- [x] #60 — b (PR #71)\n\nCloses #60\n\nFooter\n", body
  end

  def test_tick_edits_the_feature_pr_body_through_a_file
    feature.tick(60, 71)

    edit = @shell.calls.find { |c| c[:line].start_with?("gh pr edit 53") }[:line]
    assert_match(%r{--repo acme/shop --body-file \S+/tmp/autopilot/feature-pr-body.md$}, edit)
    assert_includes File.read(edit.split.last), "- [x] #60"
  end

  # #50's step split #79 into the Slices list mid-slice; the driver then ticked
  # #50 from the body it had read before the split, and #79 vanished.
  def test_tick_rereads_the_body_so_a_row_added_mid_slice_survives
    f = feature
    f.slices # cached at slice start
    split = SLICES.sub("- [ ] #51", "- [ ] #79 — split from #50\n- [ ] #51")
    @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => split } ]))

    f.tick(50, 87)

    edit = @shell.calls.find { |c| c[:line].start_with?("gh pr edit 53") }[:line]
    body = File.read(edit.split.last)
    assert_includes body, "- [ ] #79 — split from #50"
    assert_includes body, "- [x] #50"
  end

  def test_a_failed_edit_raises
    @shell.on(/^gh pr edit 53/, "HTTP 502", ok: false)

    assert_raises(Autopilot::Error) { feature.tick(60, 71) }
  end
end

class AutopilotStepTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures/autopilot", __dir__)
  # Captured from `claude -p "Reply with exactly: ok" --output-format json` on
  # the developer's machine (Claude Code, subscription auth), 2026-10-02.
  SUCCESS = JSON.parse(File.read(File.join(FIXTURES, "claude_success.json")))

  def payload(**changes) = JSON.generate(SUCCESS.merge(changes.transform_keys(&:to_s)))
  def classify(out, ok: true, timed_out: false) = Autopilot::Step.classify(Autopilot::Shell::Result.new(out, ok, timed_out))

  def test_the_captured_success_payload_is_ok
    outcome = classify(JSON.generate(SUCCESS))

    assert_equal :ok, outcome.kind
    assert_equal SUCCESS["session_id"], outcome.session_id
    assert_in_delta SUCCESS["total_cost_usd"], outcome.usage_usd
  end

  # Cache reads against writes say whether a step paid for a cold start
  # (`bin/autopilot <slug> --usage`); the write's TTL says why.
  def test_keeps_the_token_usage_and_turns
    outcome = classify(JSON.generate(SUCCESS))
    usage = SUCCESS["usage"]

    assert_equal({ "input" => usage["input_tokens"], "output" => usage["output_tokens"],
                   "cache_read" => usage["cache_read_input_tokens"],
                   "cache_write_5m" => usage.dig("cache_creation", "ephemeral_5m_input_tokens"),
                   "cache_write_1h" => usage.dig("cache_creation", "ephemeral_1h_input_tokens") }, outcome.tokens)
    assert_equal SUCCESS["num_turns"], outcome.turns
  end

  # Everything else a run reports about itself, for --usage and later tuning.
  def test_keeps_the_run_s_metrics
    metrics = classify(JSON.generate(SUCCESS)).metrics
    last = SUCCESS["usage"]["iterations"].last
    model, used = SUCCESS["modelUsage"].first

    assert_in_delta SUCCESS["duration_api_ms"] / 1000.0, metrics["api_seconds"], 0.1
    assert_equal last["input_tokens"] + last["cache_read_input_tokens"] + last["cache_creation_input_tokens"], metrics["context_end"]
    assert_equal SUCCESS["subagent_stats"]["spawned"], metrics["subagents"]
    assert_equal SUCCESS["permission_denials"].size, metrics["denials"]
    assert_equal({ "usd" => used["costUSD"], "input" => used["inputTokens"], "output" => used["outputTokens"],
                   "cache_read" => used["cacheReadInputTokens"], "cache_write" => used["cacheCreationInputTokens"] },
                 metrics["models"][model])
  end

  def test_a_payload_without_metrics_fields_keeps_what_it_has
    out = JSON.generate(SUCCESS.except("duration_api_ms", "subagent_stats", "permission_denials", "modelUsage"))

    metrics = classify(out).metrics
    assert_equal %w[context_end], metrics.keys
  end

  # A limited attempt still spent its tokens.
  def test_a_usage_limit_keeps_its_tokens_too
    out = payload(is_error: true, subtype: "success", result: "You've hit your usage limit · resets 3pm")

    assert_equal SUCCESS["usage"]["cache_read_input_tokens"], classify(out, ok: false).tokens["cache_read"]
  end

  def test_a_payload_without_usage_has_no_tokens
    out = JSON.generate(SUCCESS.except("usage", "num_turns"))

    assert_nil classify(out).tokens
    assert_nil classify(out).turns
  end

  # Older CLIs report one cache-write total and no TTL split; it counts as 5m.
  def test_a_cache_write_without_the_ttl_split_counts_as_five_minutes
    usage = SUCCESS["usage"].except("cache_creation")

    tokens = classify(payload(usage: usage)).tokens
    assert_equal usage["cache_creation_input_tokens"], tokens["cache_write_5m"]
    assert_equal 0, tokens["cache_write_1h"]
  end

  def test_a_halt_marker_in_the_result_halts
    out = payload(result: "Logged the HALT entry.\nAUTOPILOT-HALT: G2 — forecast 1,900 lines, over the bound")
    outcome = classify(out)

    assert_equal :halt, outcome.kind
    assert_equal "G2", outcome.gate
    assert_equal "forecast 1,900 lines, over the bound", outcome.reason
  end

  # The subscription limit's shape is undocumented (docs/system/autopilot.md).
  # Two signals count: an HTTP 429, or limit wording in the error text.
  def test_a_429_is_a_usage_limit
    out = payload(is_error: true, subtype: "error_during_execution", api_error_status: 429, result: "API Error")

    assert_equal :usage_limit, classify(out, ok: false).kind
  end

  def test_limit_wording_is_a_usage_limit_and_its_epoch_reset_is_read
    out = payload(is_error: true, subtype: "error_during_execution", api_error_status: nil,
                  result: "Claude AI usage limit reached|1759450000")
    outcome = classify(out, ok: false)

    assert_equal :usage_limit, outcome.kind
    assert_equal Time.at(1_759_450_000), outcome.reset_at
  end

  def test_a_spoken_reset_time_is_read_as_the_next_such_time
    now = Time.new(2026, 10, 2, 13, 0, 0)
    assert_equal Time.new(2026, 10, 2, 15, 0, 0), Autopilot::Step.reset_time("You've hit your limit · resets 3pm", now: now)
    assert_equal Time.new(2026, 10, 3, 9, 30, 0), Autopilot::Step.reset_time("limit reached, resets 9:30am", now: now)
    assert_nil Autopilot::Step.reset_time("usage limit reached", now: now)
  end

  # --max-budget-usd says "Budget limit reached"; that is not the subscription.
  def test_the_budget_cap_is_an_error_not_a_pause
    out = payload(is_error: true, subtype: "error_max_budget_usd", result: "Budget limit reached")

    assert_equal :error, classify(out, ok: false).kind
  end

  # Fail safe: anything unrecognised is an error (retry, then halt), never a
  # pause, so a wrong guess costs a halt rather than an endless wait.
  def test_an_unrecognised_failure_is_an_error
    out = payload(is_error: true, subtype: "error_during_execution", api_error_status: 500, result: "Overloaded")

    assert_equal :error, classify(out, ok: false).kind
  end

  def test_output_that_is_not_json_is_an_error
    outcome = classify("zsh: command not found: claude", ok: false)

    assert_equal :error, outcome.kind
    assert_includes outcome.reason, "command not found"
  end

  def test_a_timeout_is_its_own_kind
    assert_equal :timeout, classify("", ok: false, timed_out: true).kind
  end

  def test_builds_the_command_for_a_new_session
    shell = FakeShell.new.on(/^claude /, JSON.generate(SUCCESS))
    step = Autopilot::Step.new(shell: shell, worktree: "/w", allowed_tools: [ "Read", "Bash(git diff:*)" ])

    step.run("task_plan", 48, session_id: "s-1")

    call = shell.calls.last
    argv = call[:line]
    assert_match(%r{^claude -p /task_plan 48 }, argv)
    assert_includes argv, "--permission-mode dontAsk --permission-prompts none"
    assert_includes argv, "--allowedTools Read Bash(git diff:*)"
    assert_includes argv, "--output-format json --session-id s-1"
    assert_equal({ "AUTOPILOT" => "1", "DB_SUFFIX" => "_autopilot", "QA_HOST" => "http://localhost:3100" }, call[:env])
    assert_equal "/w", call[:chdir]
    assert_equal 90 * 60, call[:timeout]
  end

  def test_resumes_an_existing_session_and_appends_the_retry_note
    shell = FakeShell.new.on(/^claude /, JSON.generate(SUCCESS))
    step = Autopilot::Step.new(shell: shell, worktree: "/w", allowed_tools: [ "Read" ])

    step.run("pr_comment_resolver", 70, resume: "author-1", note: "No pass 1 found yet.")

    argv = shell.calls.last[:line]
    assert_includes argv, "--resume author-1"
    refute_includes argv, "--session-id"
    assert_includes argv, "/pr_comment_resolver 70\n\nNo pass 1 found yet."
  end

  # #60's /pr_submit backgrounded the suite and ended its turn to wait; in
  # `claude -p` that ends the session, so no push and no PR. An earlier
  # attempt read one denied `echo` as "Bash is denied" and stopped.
  def test_every_step_is_told_to_stay_in_the_foreground_and_split_on_a_denial
    shell = FakeShell.new.on(/^claude /, JSON.generate(SUCCESS))
    step = Autopilot::Step.new(shell: shell, worktree: "/w", allowed_tools: [ "Read" ])

    step.run("pr_submit", 60, session_id: "s-1")
    argv = step.argv("pr_submit", 60)

    rules = argv[argv.index("--append-system-prompt") + 1]
    assert_match(/foreground/, rules)
    assert_match(/run_in_background/, rules)
    assert_match(/denied/, rules)
    assert_includes shell.calls.last[:line], "--append-system-prompt"
  end

  # #49's step grepped the allowlist to learn which image tool it had, and the
  # guard denies any command naming its wiring, reads included: a halt.
  # Every review post started as a heredoc, which dontAsk denies: a wasted turn
  # per pass, and a `$(...)` activation check the same (a live run).
  def test_the_step_rules_steer_bodies_into_files_not_heredocs_or_substitution
    step = Autopilot::Step.new(shell: FakeShell.new, worktree: "/w", allowed_tools: [ "Read" ])

    argv = step.argv("pr_review", 117)
    rules = argv[argv.index("--append-system-prompt") + 1]

    assert_match(/heredocs/, rules)
    assert_includes rules, "$(...)"
    assert_includes rules, "--input <file>"
    assert_includes rules, "git commit -F"
  end

  def test_the_commands_a_step_runs_show_no_heredocs_or_substitution
    # Every command a step runs; /pick is the developer's door, never a step.
    %w[task_plan implement pr_submit pr_review pr_comment_resolver resolve_conflicts update_docs].each do |command|
      path = File.expand_path("../../.claude/commands/#{command}.md", __dir__)
      next unless File.exist?(path)

      code = shell_blocks(File.read(path))
      refute_match(/<<-?\s*['"]?EOF|\$\(/, code, "#{command} shows a heredoc or $(...), which a step's dontAsk denies")
    end
  end

  # The lines of a markdown file's bash, sh and unlabelled fenced blocks.
  def shell_blocks(markdown)
    fence = nil
    markdown.lines.each_with_object(+"") do |line, code|
      if (open = line.match(/^\s*```(\S*)\s*$/))
        fence = fence ? nil : open[1]
      elsif fence && %w[bash sh].push("").include?(fence)
        code << line
      end
    end
  end

  # The driver checked both keys before starting; a step need not redo it.
  def test_the_step_rules_state_the_activation_the_driver_checked
    activation = { branch: "feature/foo", design_doc: "docs/plans/2026-10-02-foo-design.md", log: "docs/plans/2026-10-02-foo-autopilot.md" }
    step = Autopilot::Step.new(shell: FakeShell.new, worktree: "/w", allowed_tools: [ "Read" ], activation: activation)

    argv = step.argv("implement", 49)
    rules = argv[argv.index("--append-system-prompt") + 1]

    activation.each_value { |value| assert_includes rules, value }
    assert_includes rules, "docs/system/autopilot-steps.md"
  end

  def test_without_an_activation_the_step_rules_say_nothing_of_it
    step = Autopilot::Step.new(shell: FakeShell.new, worktree: "/w", allowed_tools: [ "Read" ])
    argv = step.argv("implement", 49)

    refute_match(/Autopilot is active/, argv[argv.index("--append-system-prompt") + 1])
  end

  def test_the_step_rules_list_the_allowed_tools_so_no_step_reads_the_file
    step = Autopilot::Step.new(shell: FakeShell.new, worktree: "/w", allowed_tools: [ "Read", "Bash(git diff:*)" ])

    argv = step.argv("implement", 49)
    rules = argv[argv.index("--append-system-prompt") + 1]

    assert_includes rules, "Bash(git diff:*)"
    assert_match(/Do not read .*allowlist/m, rules)
  end

  def test_reads_the_allowlist_file_skipping_comments_and_blanks
    path = File.join(Dir.mktmpdir, "allowed.txt")
    File.write(path, "# header\nRead\n\n  Bash(git diff:*)  # trailing\n")

    assert_equal [ "Read", "Bash(git diff:*)" ], Autopilot::Step.allowlist(path)
  end

  # dontAsk denies a compound command when any part is unlisted; #60's
  # /pr_submit lost its checks to an `echo`, a `printenv` and a merge-tree.
  def test_the_shipped_allowlist_has_the_read_only_commands_steps_reach_for
    shipped = Autopilot::Step.allowlist(File.expand_path("../../.claude/autopilot-allowed-tools.txt", __dir__))

    [ "Bash(echo:*)", "Bash(printenv:*)", "Bash(git merge-tree:*)" ].each do |rule|
      assert_includes shipped, rule
    end
  end
end

class AutopilotExpectTest < Minitest::Test
  include AutopilotFixtures

  def setup
    @root = design_repo
    @shell = FakeShell.new
    @shell.on("git branch --show-current", "feat/48/top-down\n")
    @shell.on("git status --porcelain", "")
    @feature = Autopilot::Feature.new("foo", shell: @shell, root: @root)
    @expect = Autopilot::Expect.new(shell: @shell, worktree: @root, feature: @feature)
    FileUtils.mkdir_p(File.join(@root, ".llm/tasks"))
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def task_file(text = "## Progress Log\n- planned\n") = File.write(File.join(@root, ".llm/tasks/48_top_down.md"), text)
  def labels(*names) = @shell.on("gh issue view 48 --repo acme/shop --json body,labels,state", issue_json("", labels: names))

  def test_task_planned_needs_the_task_file_the_branch_and_the_label
    labels("status:in-progress")
    assert_match(/no task file/, @expect.task_planned(48))

    task_file
    @shell.on("git branch --show-current", "feature/foo\n")
    assert_match(%r{on feature/foo}, @expect.task_planned(48))

    @shell.on("git branch --show-current", "feat/48/top-down\n")
    labels("status:todo")
    assert_match(/not In Progress \(it is todo\)/, @expect.task_planned(48))

    labels("status:in-progress")
    assert_nil @expect.task_planned(48)
  end

  # /pr_submit moves the label on to status:up-for-review. A rerun of a slice
  # that is already submitted must not send it back to /task_plan.
  def test_task_planned_holds_once_the_slice_is_up_for_review
    task_file
    labels("status:up-for-review", "ready for review")

    assert_nil @expect.task_planned(48)
  end

  # feat/480/… is not #48's branch.
  def test_task_planned_does_not_take_a_longer_issue_number_for_this_one
    task_file
    labels("status:in-progress")
    @shell.on("git branch --show-current", "feat/480/other\n")

    assert_match(%r{feat/480/other}, @expect.task_planned(48))
  end

  def test_implemented_needs_the_review_line_and_a_clean_tree
    task_file
    assert_match(/Pre-PR review/, @expect.implemented(48))

    task_file("- Pre-PR review: 1 round — 0 fixed, 0 dropped by developer\n")
    @shell.on("git status --porcelain", " M app/models/x.rb\n")
    assert_match(/uncommitted/, @expect.implemented(48))

    @shell.on("git status --porcelain", "")
    assert_nil @expect.implemented(48)
  end

  def pr_list(base) = JSON.generate([ { "number" => 70, "baseRefName" => base, "headRefOid" => "abc" } ])
  # Pass 1 starts as soon as the PR exists: /pr_submit ran the checks
  # locally, and the merge gate waits for every CI check on the final head.
  def test_submitted_needs_an_open_pr_on_the_feature_branch_and_no_ci_wait
    assert_match(/no open PR/, @expect.submitted(48))

    @shell.on(%r{gh pr list .*--head feat/48/top-down}, pr_list("main"))
    assert_match(/base is main/, @expect.submitted(48))

    @shell.on(%r{gh pr list .*--head feat/48/top-down}, pr_list("feature/foo"))
    @shell.on(/gh pr checks 70/, "HTTP 502", ok: false)
    assert_nil @expect.submitted(48)
    refute @shell.ran?(/gh pr checks/)
  end

  def reviews(*pages) = JSON.generate(pages)

  # --paginate --slurp returns one array per page; a pass on page 2 counts.
  def test_reviewed_counts_self_review_passes_across_pages
    page1 = [ { "body" => "Looks fine", "commit_id" => "x" } ] * 30
    page2 = [ { "body" => "Self-review pass 1\n\n…", "commit_id" => "c1" } ]
    @shell.on(%r{gh api --paginate --slurp repos/acme/shop/pulls/70/reviews}, reviews(page1, page2))

    assert_nil @expect.reviewed(70, 1)
    assert_match(/Self-review pass 2/, @expect.reviewed(70, 2))
    assert_equal "c1", @expect.pass_commit(70, 1)
  end

  # "Could not read the reviews" must not look like "no pass yet", or the
  # retry posts the same pass twice.
  def test_unreadable_reviews_raise_rather_than_count_as_none
    @shell.on(%r{gh api --paginate --slurp repos/acme/shop/pulls/70/reviews}, "HTTP 502", ok: false)

    assert_raises(Autopilot::Error) { @expect.reviewed(70, 1) }
  end

  # The driver reads pass 1's own count to decide on pass 2 (pr_review, Two passes at most).
  def test_findings_reads_blockers_and_suggestions_from_the_pass_s_findings_line
    body = "Self-review pass 1\n\n## PR #70 Review Summary\n\n**Findings:** 1 blocking, 2 suggestions, 3 nitpicks\n"
    @shell.on(%r{gh api --paginate --slurp repos/acme/shop/pulls/70/reviews},
              reviews([ { "body" => body, "commit_id" => "c1" } ]))

    assert_equal 3, @expect.findings(70, 1)
  end

  # Reviews posted before the line existed: unknown, not zero.
  def test_findings_is_nil_when_the_pass_has_no_findings_line
    @shell.on(%r{gh api --paginate --slurp repos/acme/shop/pulls/70/reviews},
              reviews([ { "body" => "Self-review pass 1\n\n**Overall assessment:** approve", "commit_id" => "c1" } ]))

    assert_nil @expect.findings(70, 1)
  end

  def test_a_failed_head_lookup_reads_as_nil
    @shell.on(/gh pr view 70 .*headRefOid/, "HTTP 502", ok: false)

    assert_nil @expect.head(70)
  end
end

# Scripted collaborators for Autopilot::Run: a Step that replays outcomes and
# an Expect whose answers change as steps "run".
class FakeStep
  attr_reader :runs

  def initialize(script) = (@script = script) && (@runs = [])

  def run(command, arg, resume: nil, note: nil, **)
    @runs << { command: command, arg: arg, resume: resume, note: note }
    reply = @script.fetch(command).shift or raise "no scripted outcome left for #{command}"
    reply.respond_to?(:call) ? reply.call : reply
  end
end

class AutopilotRunTest < Minitest::Test
  include AutopilotFixtures

  def ok(session = "s") = Autopilot::Step::Outcome.new(kind: :ok, session_id: session, usage_usd: 1.0)

  # Expect answers: a check is missing until its step has run once (or `after`
  # runs), so the default flow is "run each step, once".
  class ScriptedExpect
    attr_accessor :head_sha, :passes, :base, :merge_check, :pass_one_findings

    def initialize = (@done = Hash.new(0)) && (@after = {}) && (@passes = 0) && (@head_sha = "c1") && (@base = "feature/foo")
    def pr_state(_pr) = { "baseRefName" => @base, "headRefOid" => @head_sha, "state" => "OPEN" }
    def merge_resolved = @merge_check&.call
    def head(_pr) = @head_sha
    def ran(name) = @done[name] += 1
    def needs(name, runs:) = @after[name] = runs
    def check(name) = @done[name] >= @after.fetch(name, 1) ? nil : "#{name} not done"
    def task_planned(_) = check(:task_plan)
    def implemented(_) = check(:implement)
    def submitted(_) = check(:pr_submit)
    def resolved(_) = nil
    def reviewed(_pr, pass) = @passes >= pass ? nil : "no pass #{pass}"
    def slice_pr(_) = { "number" => 70 }
    def pass_commit(_pr, _n) = "c1"
    def pass_count(_pr) = @passes
    def findings(_pr, _pass) = @pass_one_findings
  end

  # The feature as Run sees it: which slice PRs have merged, and the ticks.
  class FakeFeature
    attr_reader :ticks, :merged

    def initialize(shell = FakeShell.new) = (@shell = shell) && (@ticks = []) && (@merged = {})
    def tracker = @tracker ||= Autopilot::Tracker.for(Autopilot.config, shell: @shell)
    def branch = "feature/foo"
    def log_path = "docs/plans/2026-10-02-foo-autopilot.md"
    def slug = "foo"
    def pr = { "number" => 53, "isDraft" => true }
    def title(_issue) = "Top-down format"
    def merged_pr(issue) = @merged[issue]
    def tick(issue, pr) = @ticks << [ issue, pr ]
  end

  # FeatureBranch without the checkout: yields at once, git goes to the shell.
  class FakeBranch
    attr_reader :changes, :commits

    def initialize(shell) = (@shell = shell) && (@changes = 0) && (@commits = [])
    def change = (@changes += 1) && yield(self)
    def commit(paths, message) = @commits << [ paths, message ]
    def git(*args) = @shell.run("git", *args).out.strip
    def git!(*args) = git(*args)
  end

  MERGED = { "number" => 70, "headRefName" => "feat/48/top-down", "mergeCommit" => { "oid" => "5bc96eb0000" },
             "additions" => 420, "changedFiles" => 6 }.freeze

  class Notes
    attr_reader :sent

    def initialize = @sent = []
    def notify(text) = @sent << text
  end

  class Clock
    attr_reader :slept_until

    def initialize = (@slept_until = []) && (@now = Time.at(1_759_400_000))
    def now = @now
    def advance(seconds) = @now += seconds
    def sleep_until(time) = @slept_until << time
  end

  def setup
    @expect = ScriptedExpect.new
    @notes = Notes.new
    @clock = Clock.new
    @shell = FakeShell.new
    @shell.on("git branch --show-current", "feat/48/top-down\n").on("git rev-parse --short HEAD", "abc1234\n")
    @state = Autopilot::State.new(File.join(Dir.mktmpdir, "state.json"))
    @feature = FakeFeature.new(@shell)
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@dir, "docs/plans"))
    FileUtils.cp(File.expand_path("fixtures/autopilot/log.md", __dir__), File.join(@dir, @feature.log_path))
    @shell.on(/^gh pr merge 70 /) { (@feature.merged[48] = MERGED) && Autopilot::Shell::Result.new("", true, false) }
  end

  # Each fake step "does its work" by advancing the scripted expectations.
  def step_doing(name, outcome = ok) = -> { @expect.ran(name) && outcome }
  def review_pass = -> { (@expect.passes += 1) && ok("r#{@expect.passes}") }

  def happy_script
    {
      "task_plan" => [ step_doing(:task_plan) ],
      "implement" => [ step_doing(:implement, ok("author-1")) ],
      "pr_submit" => [ step_doing(:pr_submit) ],
      "pr_review" => [ review_pass, review_pass ],
      "pr_comment_resolver" => [ ok("author-1"), ok("author-1") ]
    }
  end

  def run_with(script, resolver = :fresh)
    @step = FakeStep.new(script)
    Autopilot::Run.new(step: @step, expect: @expect, notifier: @notes, state: @state, clock: @clock,
                       shell: @shell, worktree: @dir, feature: @feature, branch: @branch = FakeBranch.new(@shell), resolver: resolver)
  end

  def test_runs_a_slice_through_review_to_landed_with_a_fresh_resolver
    merged = run_with(happy_script).slice(48)

    assert_equal 70, merged["number"]
    assert_equal %w[task_plan implement pr_submit pr_review pr_comment_resolver], @step.runs.map { |r| r[:command] }
    assert_nil @step.runs.find { |r| r[:command] == "pr_comment_resolver" }[:resume]
    assert @shell.ran?("gh pr merge 70 --repo acme/shop --squash --delete-branch --match-head-commit c1")
    assert_equal [ [ 48, 70 ] ], @feature.ticks
    assert_match(/#48 landed: PR #70 merged into feature\/foo as 5bc96eb/, @notes.sent.last)
  end

  def test_pass_two_s_rulings_go_back_to_the_author_and_the_merge_takes_the_head_after_them
    heads = %w[c2 c3]
    @expect.define_singleton_method(:head) { |_pr| heads.first }
    script = happy_script.merge("pr_comment_resolver" => [ ok("author-1"), -> { heads.shift && ok("author-1") } ])
    @expect.head_sha = "c3" # what pr_state reports at merge time

    run_with(script).slice(48)

    assert_equal %w[pr_review pr_comment_resolver pr_review pr_comment_resolver], @step.runs.map { |r| r[:command] }.last(4)
    assert @shell.ran?(/gh pr merge 70 .*--match-head-commit c3$/)
  end

  # Gate `merge`: the driver checks what a prompt cannot promise.
  def test_a_pr_into_another_base_is_refused_and_halts
    @expect.base = "main"

    error = assert_raises(Autopilot::Halted) { run_with(happy_script).slice(48) }

    assert_equal "merge", error.gate
    assert_match(/targets main, not feature\/foo/, error.message)
    refute @shell.ran?(/^gh pr merge/)
    assert_empty @feature.ticks
  end

  def test_a_push_after_the_review_cycle_halts_rather_than_merging_unreviewed_code
    run = run_with(happy_script)
    @expect.define_singleton_method(:pr_state) { |_pr| { "baseRefName" => "feature/foo", "headRefOid" => "d9" } }

    error = assert_raises(Autopilot::Halted) { run.slice(48) }

    assert_equal "merge", error.gate
    assert_match(/head moved to d9/, error.message)
    refute @shell.ran?(/^gh pr merge/)
  end

  # The log's wall time is the whole slice, not only its steps: the CI wait
  # before the merge can be the longest part of it.
  def test_the_ci_wait_counts_toward_the_slice_s_wall_time
    @shell.on(/^gh pr checks 70 /) { (@clock.advance(1200) && Autopilot::Shell::Result.new("", true, false)) }

    run_with(happy_script).slice(48)

    wait = @state.get(48, "usage").find { |u| u["step"] == "CI wait, PR #70" }
    assert_equal 1200, wait["seconds"]
    assert_includes File.read(File.join(@dir, @feature.log_path)), "| #48 | `CI wait, PR #70` | 20m 0s | $0.00 | 0 | 0 |"
  end

  def test_red_ci_halts_without_merging
    @shell.on(/^gh pr checks 70 .*--watch --fail-fast/, "test\tfail\t4m\thttps://ci/1\n", ok: false)

    error = assert_raises(Autopilot::Halted) { run_with(happy_script).slice(48) }

    assert_match(/CI is red on PR #70: test\tfail/, error.message)
    refute @shell.ran?(/^gh pr merge/)
    refute @shell.ran?(/^gh run rerun/), "no Actions run in the checks, nothing to rerun"
    assert @shell.ran?(/gh issue edit 48 .*--add-label status:blocked/)
  end

  RED_RUN = "test\tfail\t2m20s\thttps://github.com/o/r/actions/runs/371/job/111\n" * 2

  # A flaky test gets one rerun of the failed jobs before it halts the run.
  def test_red_ci_that_a_rerun_turns_green_merges
    @shell.on(/^gh pr checks 70 .*--watch --fail-fast/, RED_RUN, ok: false)

    run_with(happy_script).slice(48)

    assert @shell.ran?(/^gh run rerun 371 --failed/)
    assert @shell.ran?(/^gh run watch 371 .*--exit-status/)
    assert @shell.ran?(/^gh pr merge 70/)
    assert(@notes.sent.any? { |note| note.include?("rerunning its failed jobs once") })
    assert(@state.get(48, "usage").any? { |u| u["step"] == "CI rerun, PR #70" })
  end

  def test_red_ci_after_its_rerun_halts_without_merging
    @shell.on(/^gh pr checks 70 .*--watch --fail-fast/, RED_RUN, ok: false)
    @shell.on(/^gh run watch 371 .*--exit-status/, ok: false)

    error = assert_raises(Autopilot::Halted) { run_with(happy_script).slice(48) }

    assert_match(/CI is red on PR #70: .*still red after one rerun/, error.message)
    assert_equal 1, error.message.scan("test\tfail").size, "a check listed twice is reported once"
    assert_equal 1, @shell.lines.grep(/^gh run rerun/).size
    refute @shell.ran?(/^gh pr merge/)
  end

  CODEQL_RED = "CodeQL\tfail\t3m\thttps://github.com/o/r/actions/runs/500/job/9\n"

  def checks_json(*buckets) = JSON.generate(buckets.map { |name, bucket| { "name" => name, "bucket" => bucket } })

  # --fail-fast stops at CodeQL's red while the real checks still run. The
  # driver waits them out without it and merges when only CodeQL is red, as
  # /pr_review's Land it does.
  def test_an_informational_red_alone_waits_out_the_rest_and_merges
    @shell.on(/^gh pr checks 70 .*--watch --fail-fast/, CODEQL_RED, ok: false)
    @shell.on(/^gh pr checks 70 --repo acme\/shop --watch$/, CODEQL_RED, ok: false)
    @shell.on(/^gh pr checks 70 .*--json name,bucket/, checks_json(%w[CodeQL fail], %w[test pass], %w[lint pass]), ok: false)

    run_with(happy_script).slice(48)

    assert @shell.ran?(/^gh pr checks 70 --repo acme\/shop --watch$/), "the rest waited for without --fail-fast"
    refute @shell.ran?(/^gh run rerun/), "an informational check is never rerun"
    assert @shell.ran?(/^gh pr merge 70/)
  end

  def test_an_informational_red_with_a_real_one_behind_it_is_rerun_without_it
    @shell.on(/^gh pr checks 70 .*--watch --fail-fast/, CODEQL_RED, ok: false)
    @shell.on(/^gh pr checks 70 --repo acme\/shop --watch$/, CODEQL_RED + RED_RUN, ok: false)
    answers = [ checks_json(%w[CodeQL fail], %w[test pending]), checks_json(%w[CodeQL fail], %w[test fail]) ]
    @shell.on(/^gh pr checks 70 .*--json name,bucket/) { Autopilot::Shell::Result.new(answers.shift || answers.last, false, false) }
    @shell.on(/^gh run watch 371 .*--exit-status/, ok: false)

    error = assert_raises(Autopilot::Halted) { run_with(happy_script).slice(48) }

    assert_match(/still red after one rerun/, error.message)
    assert @shell.ran?(/^gh run rerun 371 --failed/)
    refute @shell.ran?(/^gh run rerun 500/), "CodeQL's run is not rerun"
    refute @shell.ran?(/^gh pr merge/)
  end

  def test_a_real_red_beside_an_informational_one_is_not_waited_past
    @shell.on(/^gh pr checks 70 .*--watch --fail-fast/, CODEQL_RED + RED_RUN, ok: false)
    @shell.on(/^gh pr checks 70 .*--json name,bucket/, checks_json(%w[CodeQL fail], %w[test fail]), ok: false)

    run_with(happy_script).slice(48)

    refute @shell.ran?(/^gh pr checks 70 --repo acme\/shop --watch$/)
    assert @shell.ran?(/^gh run rerun 371 --failed/)
    refute @shell.ran?(/^gh run rerun 500/)
    assert @shell.ran?(/^gh pr merge 70/), "the rerun turned the real check green"
  end

  def test_a_rerun_gh_refuses_halts_without_merging
    @shell.on(/^gh pr checks 70 .*--watch --fail-fast/, RED_RUN, ok: false)
    @shell.on(/^gh run rerun 371/, "run 371 cannot be rerun", ok: false)

    error = assert_raises(Autopilot::Halted) { run_with(happy_script).slice(48) }

    assert_match(/still red after one rerun/, error.message)
    refute @shell.ran?(/^gh run watch 371 .*--exit-status/)
    refute @shell.ran?(/^gh pr merge/)
  end

  # A rerun after a stop mid-landing: nothing is planned, submitted or merged again.
  def test_a_slice_already_merged_only_finishes_landing
    @feature.merged[48] = MERGED

    run_with(happy_script).slice(48)

    assert_empty @step.runs
    refute @shell.ran?(/^gh pr (merge|checks)/)
    assert_equal [ [ 48, 70 ] ], @feature.ticks
  end

  def test_main_already_in_the_feature_branch_is_not_merged_again
    run_with(happy_script).slice(48)

    assert @shell.ran?("git fetch origin main")
    refute @shell.ran?(/^git merge --no-edit/)
  end

  # A developer's `merge.ff=only` refused the merge commit a diverged feature
  # branch needs: the merge failed with no conflict, and the run stopped.
  def test_merging_main_works_under_a_fast_forward_only_config
    repo = Dir.mktmpdir
    git = ->(*args) { Open3.capture2e("git", *args, chdir: repo) }
    git.("init", "-q", "-b", "main")
    git.("config", "user.email", "t@t")
    git.("config", "user.name", "t")
    git.("config", "merge.ff", "only")
    git.("commit", "-q", "--allow-empty", "-m", "base")
    git.("checkout", "-q", "-b", "feature/foo")
    git.("commit", "-q", "--allow-empty", "-m", "slice")
    git.("checkout", "-q", "main")
    git.("commit", "-q", "--allow-empty", "-m", "main moved")
    git.("update-ref", "refs/remotes/origin/main", "main")
    git.("checkout", "-q", "feature/foo")

    out, status = Open3.capture2e(*Autopilot::Run::MERGE_MAIN, chdir: repo)

    assert status.success?, out
    assert_equal "", git.("rev-list", "HEAD..origin/main").first
  ensure
    FileUtils.remove_entry(repo)
  end

  def conflicting!
    @shell.on("git merge-base --is-ancestor origin/main HEAD", "", ok: false)
    @shell.on("git merge --no-edit --no-ff origin/main", "CONFLICT (content): Merge conflict in Gemfile", ok: false)
    @shell.on("git rev-parse -q --verify MERGE_HEAD", "abc\n")
  end

  def test_a_conflict_runs_resolve_conflicts_then_the_driver_proves_the_suite_green
    conflicting!
    script = happy_script.merge("resolve_conflicts" => [ ok ])

    run_with(script).slice(48)

    resolve = @step.runs.find { |r| r[:command] == "resolve_conflicts" }
    assert_equal "feature/foo", resolve[:arg], "the argument is <BASE> for the step's activation check"
    suite = @shell.calls.find { |c| c[:line] == "bin/test" }
    assert_equal "_autopilot", suite[:env]["DB_SUFFIX"]
    assert_equal [ [ 48, 70 ] ], @feature.ticks
  end

  def test_a_conflict_still_red_after_the_step_halts_and_leaves_the_slice_unticked
    conflicting!
    @shell.on("bin/test", "3 failures", ok: false)
    script = happy_script.merge("resolve_conflicts" => [ ok ])

    error = assert_raises(Autopilot::Halted) { run_with(script).slice(48) }

    assert_match(/suite is red after \/resolve_conflicts/, error.message)
    assert_empty @feature.ticks, "a ticked slice would be skipped by the rerun, with main unmerged"
    assert @shell.ran?(/gh issue edit 48 .*--add-label status:blocked/)
  end

  def test_a_conflict_the_step_cannot_finish_halts_after_one_retry
    conflicting!
    @expect.merge_check = -> { "the merge of origin/main is still in progress" }
    script = happy_script.merge("resolve_conflicts" => [ ok, ok ])

    error = assert_raises(Autopilot::Halted) { run_with(script).slice(48) }

    assert_match(/still in progress \(after one retry\)/, error.message)
    refute @shell.ran?("bin/test")
  end

  def test_landing_records_the_slice_in_the_log_and_commits_it_once
    FileUtils.mkdir_p(File.join(@dir, ".llm/tasks"))
    File.write(File.join(@dir, ".llm/tasks/48_top_down.md"), "- 2026-10-02: Pre-PR review: 2 rounds — 5 fixed, 1 dropped by developer\n")
    run = run_with(happy_script)
    run.slice(48)

    log = File.read(File.join(@dir, @feature.log_path))
    assert_includes log, "### #48 — Top-down format (PR #70, merged 5bc96eb)"
    assert_includes log, "| 420 | 6 | 1 | 5 | 1 | 0m 0s | $5.00 |"
    assert_includes log, "| #48 | `/task_plan 48` |"
    assert_equal [ [ [ @feature.log_path ], "Record #48 in the autopilot log" ] ], @branch.commits

    run.slice(48) # a rerun after a stop mid-landing
    assert_equal 1, @branch.commits.size, "nothing new to record, nothing committed"
  end

  def write(path, text)
    FileUtils.mkdir_p(File.dirname(File.join(@dir, path)))
    File.write(File.join(@dir, path), text)
  end

  def log = File.read(File.join(@dir, @feature.log_path))

  def test_finalize_resolves_the_feature_s_placeholders_finishes_the_log_then_readies_the_pr
    write("docs/system/foo.md", "# Foo\n\n**Status:** Draft — created for #48. Filled by slice 2.\n")
    write("docs/sop/other.md", "# Other\n\n**Status:** Draft — created for #12.\n")
    write("docs/system/opinion.md", "# Formats\n\n**Status:** Draft\n")
    @state.append(48, "usage", { "step" => "/task_plan 48", "kind" => "ok", "usd" => 2.5, "at" => "2025-10-02T09:00:00+00:00" })
    update_docs = -> { write("docs/system/foo.md", "# Foo\n\n**Status:** Current\n") && ok }

    run_with("update_docs" => [ update_docs ]).finalize(48, [ 47, 48 ])

    docs = @step.runs.find { |r| r[:command] == "update_docs" }
    assert_equal "docs/system/foo.md", docs[:arg], "only this feature's placeholders; an opinion's plain Draft is left"
    assert_match(/commit, and do not push/, docs[:note])
    assert_match(/Do not halt/, docs[:note], "a halt from the step would label nothing and hold no finish")
    assert_includes log, "- **costly** · D47-2"
    assert_includes log, "**Run:** #{Time.iso8601("2025-10-02T09:00:00+00:00").iso8601} → #{@clock.now.iso8601} · **Usage:** $3.50 (estimate)"
    assert_equal [ [ [ @feature.log_path ], "Finish the autopilot log" ] ], @branch.commits
    assert @shell.ran?("gh pr ready 53 --repo acme/shop")
    assert_match(/feature\/foo is ready for review/, @notes.sent.last)
  end

  def test_a_placeholder_still_draft_after_update_docs_halts_and_the_pr_stays_a_draft
    write("docs/system/foo.md", "**Status:** Draft — created for #48.\n")

    error = assert_raises(Autopilot::Halted) { run_with("update_docs" => [ ok, ok ]).finalize(48, [ 48 ]) }

    assert_match(%r{still Draft: docs/system/foo.md \(after one retry\)}, error.message)
    refute @shell.ran?(/^gh pr ready/)
  end

  def test_without_placeholders_there_is_no_update_docs_step
    run_with({}).finalize(48, [ 48 ])

    assert_empty @step.runs
    assert @shell.ran?(/^gh pr ready 53/)
  end

  def test_the_capture_hook_runs_only_when_executable_and_its_output_lands_in_qa
    write("script/qa/foo-capture", "#!/bin/sh\n")
    run_with({}).finalize(48, [ 48 ])
    refute @shell.ran?(/foo-capture/), "not executable: skipped"

    File.chmod(0o755, File.join(@dir, "script/qa/foo-capture"))
    @shell.on(/foo-capture$/, "wrote tmp/qa/top-down.png\n")
    run_with({}).finalize(48, [ 48 ])

    assert_match(/## QA — how to check the whole feature\n\n<!-- capture -->\n\*\*Capture:\*\* `script\/qa\/foo-capture` ran\. Last lines:\n\n```\nwrote tmp\/qa\/top-down.png\n```/, log)
  end

  # #69's metrics read these; the run is many full sessions out of the
  # developer's weekly allowance.
  def test_records_each_step_s_usage_estimate
    run_with(happy_script).slice(48)

    usage = @state.get(48, "usage").reject { |u| u["kind"] == "driver" }
    assert_equal %w[/task_plan /implement /pr_submit /pr_review /pr_comment_resolver], usage.map { |u| u["step"].split.first }
    assert_equal [ 1.0 ] * 5, usage.map { |u| u["usd"] }
  end

  def summarised(session, text) = Autopilot::Step::Outcome.new(kind: :ok, session_id: session, usage_usd: 1.0, result: text)

  def test_resolver_resume_resumes_the_author_and_says_so
    run_with(happy_script, :resume).slice(48)

    resolver = @state.get(48, "usage").find { |u| u["step"].start_with?("/pr_comment_resolver") }
    assert_equal "resume", resolver["variant"]
    assert_nil @state.get(48, "usage").find { |u| u["step"].start_with?("/implement") }["variant"]
  end

  # The experiment: a new session that starts from a handoff file instead of
  # carrying /implement's whole context into every call.
  def test_a_fresh_resolver_starts_a_new_session_from_a_handoff_file
    FileUtils.mkdir_p(File.join(@dir, ".llm/tasks"))
    File.write(File.join(@dir, ".llm/tasks/48_top_down.md"), "# task\n")
    script = happy_script.merge("implement" => [ step_doing(:implement, summarised("author-1", "Built the top-down format.")) ])
    Autopilot::Run.new(step: @step = FakeStep.new(script), expect: @expect, notifier: @notes, state: @state, clock: @clock,
                       shell: @shell, worktree: @dir, feature: @feature, branch: FakeBranch.new(@shell), resolver: :fresh).slice(48)

    run = @step.runs.find { |r| r[:command] == "pr_comment_resolver" }
    assert_nil run[:resume]
    handoff = File.join(@dir, "tmp/autopilot/handoff-48.md")
    assert_includes run[:note], "tmp/autopilot/handoff-48.md"
    text = File.read(handoff)
    assert_includes text, ".llm/tasks/48_top_down.md"
    assert_includes text, "Built the top-down format."
    assert_includes text, "PR #70"
    assert_includes text, "feature/foo"
    assert_equal "fresh", @state.get(48, "usage").find { |u| u["step"].start_with?("/pr_comment_resolver") }["variant"]
  end

  # Pass 2's fresh session gets what pass 1's resolver did, too.
  def test_a_fresh_pass_two_resolver_hands_off_pass_one_s_summary
    @expect.head_sha = "c2"
    script = happy_script.merge("pr_comment_resolver" => [ summarised("fix-1", "Fixed the nil guard."), ok("fix-2") ])
    Autopilot::Run.new(step: @step = FakeStep.new(script), expect: @expect, notifier: @notes, state: @state, clock: @clock,
                       shell: @shell, worktree: @dir, feature: @feature, branch: FakeBranch.new(@shell), resolver: :fresh).slice(48)

    assert_equal 2, @step.runs.count { |r| r[:command] == "pr_comment_resolver" }
    assert_includes File.read(File.join(@dir, "tmp/autopilot/handoff-48.md")), "Fixed the nil guard."
  end

  def test_records_each_step_s_tokens_and_turns
    tokens = { "input" => 1, "output" => 2, "cache_read" => 3, "cache_write_5m" => 4, "cache_write_1h" => 5 }
    measured = Autopilot::Step::Outcome.new(kind: :ok, session_id: "author-1", usage_usd: 1.0, tokens: tokens, turns: 7)
    script = happy_script.merge("implement" => [ -> { @expect.ran(:implement) && measured } ])
    run_with(script).slice(48)

    implement = @state.get(48, "usage").find { |u| u["step"] == "/implement 48" }
    assert_equal tokens, implement["tokens"]
    assert_equal 7, implement["turns"]
  end

  def test_records_each_step_s_metrics
    metrics = { "api_seconds" => 90.5, "context_end" => 80_000, "subagents" => 2, "denials" => 1, "models" => { "m" => { "usd" => 1.0 } } }
    measured = Autopilot::Step::Outcome.new(kind: :ok, session_id: "author-1", usage_usd: 1.0, metrics: metrics)
    run_with(happy_script.merge("implement" => [ -> { @expect.ran(:implement) && measured } ])).slice(48)

    implement = @state.get(48, "usage").find { |u| u["step"] == "/implement 48" }
    metrics.each { |key, value| assert_equal value, implement[key], key }
  end

  # Wall time per attempt, for the log's metrics.
  def test_records_when_each_step_started_and_how_long_it_took
    script = happy_script.merge("implement" => [ -> { @clock.advance(150) && @expect.ran(:implement) && ok("author-1") } ])
    run_with(script).slice(48)

    implement = @state.get(48, "usage").find { |u| u["step"] == "/implement 48" }
    assert_equal 150, implement["seconds"]
    assert_equal Time.at(1_759_400_000).iso8601, implement["at"]
  end

  def test_pass_two_runs_only_when_the_resolver_moved_head_past_pass_one
    @expect.head_sha = "c2"
    run_with(happy_script).slice(48)

    assert_equal 2, @step.runs.count { |r| r[:command] == "pr_review" }
    assert_nil @step.runs.select { |r| r[:command] == "pr_review" }.last[:resume], "a review pass is never resumed"
  end

  # Nitpicks never trigger pass 2: a resolver push of only nitpick or log
  # commits lands without another review (ADR 0014).
  def test_pass_two_is_skipped_when_pass_one_found_no_blockers_or_suggestions
    @expect.head_sha = "c2"
    @expect.pass_one_findings = 0
    run_with(happy_script).slice(48)

    assert_equal 1, @step.runs.count { |r| r[:command] == "pr_review" }
    assert @shell.ran?(/gh pr merge 70 .*--match-head-commit c2$/)
  end

  def test_pass_two_runs_when_pass_one_found_blockers_or_suggestions_and_head_moved
    @expect.head_sha = "c2"
    @expect.pass_one_findings = 2
    run_with(happy_script).slice(48)

    assert_equal 2, @step.runs.count { |r| r[:command] == "pr_review" }
  end

  # An unreadable head is not "moved": guessing would post a spurious pass 2.
  def test_an_unreadable_pr_head_stops_rather_than_running_pass_two
    @expect.head_sha = nil

    error = assert_raises(Autopilot::Error) { run_with(happy_script).slice(48) }

    assert_match(/cannot read PR #70's head/, error.message)
    assert_equal 1, @step.runs.count { |r| r[:command] == "pr_review" }
  end

  # Rerunning the driver after a halt picks up where it stopped: a step whose
  # expectation already holds is not run again.
  def test_a_step_whose_expectation_already_holds_is_skipped
    @expect.ran(:task_plan)
    @expect.ran(:implement)
    @state.set(48, "author", "author-1")

    run_with(happy_script).slice(48)

    assert_equal %w[pr_submit pr_review pr_comment_resolver], @step.runs.map { |r| r[:command] }
  end

  def test_a_failed_expectation_is_retried_once_with_a_note
    @expect.needs(:task_plan, runs: 2)
    script = happy_script.merge("task_plan" => [ step_doing(:task_plan), step_doing(:task_plan) ])

    run_with(script).slice(48)

    plans = @step.runs.select { |r| r[:command] == "task_plan" }
    assert_equal 2, plans.size
    assert_nil plans.first[:note]
    assert_match(/ended without: task_plan not done/, plans.last[:note])
  end

  # The run guide sends the developer to the state file and the step's
  # session to see why a step needed its retry.
  def test_each_attempt_records_its_session_and_why_it_fell_short
    @expect.needs(:task_plan, runs: 2)
    script = happy_script.merge("task_plan" => [ -> { @expect.ran(:task_plan) && ok("plan-1") }, step_doing(:task_plan) ])

    run_with(script).slice(48)

    first, second = @state.get(48, "usage").select { |u| u["step"] == "/task_plan 48" }
    assert_equal "plan-1", first["session"]
    assert_equal "task_plan not done", first["failure"]
    refute second.key?("failure")
  end

  def test_a_second_failure_halts_on_the_issue_with_the_marker
    @expect.needs(:task_plan, runs: 3)
    script = happy_script.merge("task_plan" => [ step_doing(:task_plan), step_doing(:task_plan) ])

    error = assert_raises(Autopilot::Halted) { run_with(script).slice(48) }

    assert_equal "halt", error.gate
    assert @shell.ran?(/gh issue edit 48 .*--add-label status:blocked --remove-label status:todo --remove-label status:in-progress --remove-label status:up-for-review/),
           "a halt after /pr_submit must not leave up-for-review beside blocked"
    comment = @shell.calls.find { |c| c[:line].start_with?("gh issue comment 48") }[:line]
    assert_includes comment, "#### HALT · `halt` · /task_plan 48: task_plan not done (after one retry)"
    assert_includes comment, "- **Resume:**"
    assert comment.rstrip.end_with?(Autopilot::MARKER)
    assert_match(/Halted on #48/, @notes.sent.last)
  end

  def test_a_halt_under_github_projects_moves_the_card_to_blocked
    tier!("github-projects")
    @shell.on(/^gh api graphql -f query=\{ repository\(owner: "acme", name: "shop"\) \{ issue\(number: 48\)/, board_items_json("PVTI_48"))
    @expect.needs(:task_plan, runs: 3)
    script = happy_script.merge("task_plan" => [ step_doing(:task_plan), step_doing(:task_plan) ])

    assert_raises(Autopilot::Halted) { run_with(script).slice(48) }

    assert @shell.ran?("gh project item-edit --project-id PVT_1 --id PVTI_48 --field-id PVTSSF_1 --single-select-option-id opt-blocked")
    refute @shell.ran?(/gh issue edit/), "no status labels on a board tier"
    comment = @shell.calls.find { |c| c[:line].start_with?("gh issue comment 48") }[:line]
    assert_includes comment, "#### HALT · `halt` · /task_plan 48"
  end

  def test_a_halt_under_beads_blocks_the_bead_and_posts_on_the_feature_pr
    tier!("beads")
    @expect.needs(:task_plan, runs: 3)
    script = happy_script.merge("task_plan" => [ step_doing(:task_plan), step_doing(:task_plan) ])

    error = assert_raises(Autopilot::Halted) { run_with(script).slice("bd-b2") }

    assert_equal "bd-b2", error.issue
    assert @shell.ran?("bd update b2 --status blocked")
    assert @shell.ran?("bd label remove b2 lifecycle:up_for_review"), "a Blocked bead must not still read as up for review"
    comment = @shell.calls.find { |c| c[:line].start_with?("gh pr comment 53") }&.fetch(:line)
    assert comment, "there is no GitHub issue under beads: the entry goes on the feature PR"
    assert_includes comment, "#### HALT · `halt` · /task_plan bd-b2"
    assert_includes comment, "clear Blocked on bd-b2"
    refute @shell.ran?(/^gh issue /)
  end

  def test_a_halt_from_the_step_stops_at_once_without_a_retry
    halt = Autopilot::Step::Outcome.new(kind: :halt, gate: "G2", reason: "over the bound")
    script = happy_script.merge("task_plan" => [ halt ])

    error = assert_raises(Autopilot::Halted) { run_with(script).slice(48) }

    assert_equal "G2", error.gate
    assert_equal 1, @step.runs.size
    refute @shell.ran?(/gh issue edit/), "the step already followed the halt protocol"
  end

  def test_a_usage_limit_pauses_until_reset_and_reruns_without_using_the_retry
    reset = Time.at(1_759_403_600)
    limit = Autopilot::Step::Outcome.new(kind: :usage_limit, reason: "usage limit reached", reset_at: reset)
    @expect.needs(:task_plan, runs: 2)
    script = happy_script.merge("task_plan" => [ limit, step_doing(:task_plan), step_doing(:task_plan) ])

    run_with(script).slice(48)

    assert_equal [ reset ], @clock.slept_until
    plans = @step.runs.select { |r| r[:command] == "task_plan" }
    assert_equal 3, plans.size, "the pause did not count as the step's one retry"
    assert_nil plans[1][:note], "the rerun after a pause is the same attempt, not a retry"
    assert_equal 1, @state.get(48, "pauses").size
  end

  def test_a_pause_with_no_stated_reset_waits_thirty_minutes
    limit = Autopilot::Step::Outcome.new(kind: :usage_limit, reason: "usage limit reached")
    script = happy_script.merge("task_plan" => [ limit, step_doing(:task_plan) ])

    run_with(script).slice(48)

    assert_equal [ @clock.now + (30 * 60) ], @clock.slept_until
  end

  def test_twelve_pauses_in_a_row_halt
    limit = Autopilot::Step::Outcome.new(kind: :usage_limit, reason: "usage limit reached")
    script = happy_script.merge("task_plan" => [ limit ] * 13)

    error = assert_raises(Autopilot::Halted) { run_with(script).slice(48) }

    assert_match(/usage limit 13 times/, error.message)
    assert_equal 12, @clock.slept_until.size
  end

  # On Linux or CI there is no osascript; the notice must still go out and the
  # run must not crash after doing its work.
  def test_desktop_notification_only_where_osascript_exists
    @shell.on("sh -c command -v osascript", "", ok: false)
    Autopilot::Notifier.new(shell: @shell, feature_pr: 66).notify("hello")

    assert @shell.ran?(/^gh pr comment 66/)
    refute @shell.ran?(/^osascript/)

    @shell.on("sh -c command -v osascript", "/usr/bin/osascript\n")
    Autopilot::Notifier.new(shell: @shell, feature_pr: 66).notify("hello")
    assert @shell.ran?(/^osascript -e display notification "hello"/)
  end

  def test_every_notice_carries_the_marker
    run_with(happy_script).slice(48)

    notifier = Autopilot::Notifier.new(shell: @shell, feature_pr: 66, desktop: false)
    notifier.notify("hello")
    body = @shell.calls.last[:line]
    assert_match(/^gh pr comment 66 --repo acme\/shop --body hello/, body)
    assert body.end_with?(Autopilot::MARKER)
  end
end

class AutopilotResumeTest < Minitest::Test
  include AutopilotFixtures

  LOG = "docs/plans/2026-10-02-foo-autopilot.md"
  HALT = <<~MD
    #### HALT · `halt` · /task_plan 60: no task file (after one retry)
    - **Where:** bin/autopilot on `feature/foo` at abc1234
    - **Resume:** answer under **Needs**, clear Blocked on #60 (docs/system/autopilot-steps.md, Tracker tiers), then `bin/autopilot foo`
  MD

  def setup
    @root = design_repo
    File.write(File.join(@root, LOG), "# Foo — autopilot log\n\n## Halts and pauses\n\n## Metrics\n")
    @shell = FakeShell.new
    @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => SLICES } ]))
    @shell.on("git branch --show-current", "feat/60/storage\n")
    @shell.on(/gh pr list .*--base feature\/foo --state merged/, "[]")
    @feature = Autopilot::Feature.new("foo", shell: @shell, root: @root)
    @resume = Autopilot::Resume.new(feature: @feature, shell: @shell, worktree: @root)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def comments(*bodies) = JSON.generate("comments" => bodies.map { |body| { "body" => body } })

  def test_copies_a_halt_posted_on_an_issue_into_the_log_on_the_feature_branch
    @shell.on(/gh issue view 60 .*--json comments/, comments("#{HALT}\n#{Autopilot::MARKER}\n", "a person's note"))

    assert_equal 1, @resume.copy_halts

    log = File.read(File.join(@root, LOG))
    assert_match(/## Halts and pauses\n\n#### HALT · `halt` · \/task_plan 60/, log)
    refute_includes log, Autopilot::MARKER
    refute_includes log, "a person's note"
    order = @shell.lines.grep(/^git (fetch|checkout|add|commit|push)/)
    assert_equal "git fetch origin feature/foo", order.first
    assert_equal "git checkout --detach origin/feature/foo", order[1],
                 "detached at the remote, so a feature branch checked out elsewhere is no obstacle"
    assert_includes order, "git push origin HEAD:feature/foo"
    assert_equal "git checkout feat/60/storage", order.last, "returns to the branch it was on"
  end

  # The developer often has feature/<slug> checked out in the main checkout
  # (after landing a slice by hand). Any git step that fails must stop the
  # copy, not commit the entry wherever HEAD happens to be.
  def test_a_failed_git_step_stops_the_copy_and_says_why
    @shell.on(/gh issue view 60 .*--json comments/, comments("#{HALT}\n#{Autopilot::MARKER}\n"))
    @shell.on("git checkout --detach origin/feature/foo", "fatal: invalid reference: origin/feature/foo", ok: false)

    error = assert_raises(Autopilot::Error) { @resume.copy_halts }

    assert_match(/git checkout --detach origin\/feature\/foo failed: fatal: invalid reference/, error.message)
    refute @shell.ran?(/^git (add|commit|push)/)
    assert_equal "git checkout feat/60/storage", @shell.lines.grep(/^git checkout/).last
  end

  def test_a_rejected_push_is_an_error_not_a_copy
    @shell.on(/gh issue view 60 .*--json comments/, comments("#{HALT}\n#{Autopilot::MARKER}\n"))
    @shell.on("git push origin HEAD:feature/foo", "! [rejected] (fetch first)", ok: false)

    assert_raises(Autopilot::Error) { @resume.copy_halts }
    assert_equal "git checkout feat/60/storage", @shell.lines.grep(/^git checkout/).last
  end

  def test_a_halt_already_in_the_log_is_not_copied_twice
    @shell.on(/gh issue view 60 .*--json comments/, comments("#{HALT}\n#{Autopilot::MARKER}\n"))
    @resume.copy_halts
    @shell.calls.clear

    assert_equal 0, @resume.copy_halts
    refute @shell.ran?(/^git commit/)
    assert_equal 1, File.read(File.join(@root, LOG)).scan("#### HALT").size
  end

  # The worktree is on a slice branch whose log predates the copy; the feature
  # branch already has the entry. Its copy is the one that counts.
  def test_dedupes_against_the_feature_branch_copy_of_the_log
    @shell.on(/gh issue view 60 .*--json comments/, comments("#{HALT}\n#{Autopilot::MARKER}\n"))
    log = File.join(@root, LOG)
    @shell.on("git checkout --detach origin/feature/foo") do
      File.write(log, "# Foo — autopilot log\n\n## Halts and pauses\n\n#{HALT}\n## Metrics\n")
      Autopilot::Shell::Result.new("", true, false)
    end

    assert_equal 0, @resume.copy_halts
    refute @shell.ran?(/^git commit/)
    assert_equal "git checkout feat/60/storage", @shell.lines.grep(/^git checkout/).last
  end

  def test_a_failed_commit_leaves_no_edited_log_behind
    @shell.on(/gh issue view 60 .*--json comments/, comments("#{HALT}\n#{Autopilot::MARKER}\n"))
    @shell.on(/^git commit/, "error: gpg failed to sign the data", ok: false)

    assert_raises(Autopilot::Error) { @resume.copy_halts }

    checkouts = @shell.lines.grep(/^git checkout/)
    assert_equal [ "git checkout --detach origin/feature/foo", "git checkout -- #{LOG}", "git checkout feat/60/storage" ], checkouts
  end

  # A previous run killed mid-copy can leave the worktree detached. Carrying
  # on would plan the next slice on a detached HEAD; say so instead.
  def test_a_detached_worktree_stops_the_copy_before_it_starts
    @shell.on(/gh issue view 60 .*--json comments/, comments("#{HALT}\n#{Autopilot::MARKER}\n"))
    @shell.on("git branch --show-current", "")

    error = assert_raises(Autopilot::Error) { @resume.copy_halts }

    assert_match(/detached HEAD/, error.message)
    refute @shell.ran?(/^git (fetch|checkout|commit)/)
  end

  # A cleared halt leaves the issue with no status label; the driver puts the
  # right one back (docs/system/autopilot-steps.md, HALT entry, Resume).
  def test_restores_in_progress_when_the_slice_branch_exists
    @shell.on(%r{git ls-remote --heads origin refs/heads/feat/60/\*}, "abc\trefs/heads/feat/60/storage\n")
    @shell.on(%r{gh pr list --repo acme/shop --head feat/60/storage --state open}, "[]")
    @resume.restore_state(Autopilot::Slice.new(issue: 60, state: nil))

    assert @shell.ran?(/gh issue edit 60 --repo acme\/shop --add-label status:in-progress/)
  end

  # A halt in /pr_review or the resolver: the slice has an open PR, so it is
  # up for review, not back in progress.
  def test_restores_up_for_review_when_the_slice_has_an_open_pr
    @shell.on(%r{git ls-remote --heads origin refs/heads/feat/60/\*}, "abc\trefs/heads/feat/60/storage\n")
    @shell.on(%r{gh pr list --repo acme/shop --head feat/60/storage --state open},
              JSON.generate([ { "number" => 71 } ]))
    @resume.restore_state(Autopilot::Slice.new(issue: 60, state: nil))

    assert @shell.ran?(/gh issue edit 60 .*--add-label status:up-for-review/)
  end

  # gh down is not "no PR": guessing in-progress would mislabel a slice under
  # review without a word. It stops instead, like every other gh failure.
  def test_an_unreadable_pr_list_raises_rather_than_guessing_a_label
    @shell.on(%r{git ls-remote --heads origin refs/heads/feat/60/\*}, "abc\trefs/heads/feat/60/storage\n")
    @shell.on(%r{gh pr list --repo acme/shop --head feat/60/storage --state open}, "HTTP 502", ok: false)

    assert_raises(Autopilot::Error) { @resume.restore_state(Autopilot::Slice.new(issue: 60, state: nil)) }
    refute @shell.ran?(/gh issue edit/)
  end

  # A halt while landing: the PR merged and its branch is gone, but the slice
  # is not done until it is ticked.
  def test_restores_up_for_review_when_the_slice_already_merged
    @shell.on(/gh pr list .*--base feature\/foo --state merged/,
              JSON.generate([ { "number" => 71, "headRefName" => "feat/60/storage" } ]))
    @resume.restore_state(Autopilot::Slice.new(issue: 60, state: nil))

    assert @shell.ran?(/gh issue edit 60 .*--add-label status:up-for-review/)
  end

  def test_restores_todo_when_the_slice_was_never_planned
    @resume.restore_state(Autopilot::Slice.new(issue: 60, state: nil))

    assert @shell.ran?(/gh issue edit 60 .*--add-label status:todo/)
  end

  def test_leaves_a_status_label_alone
    @resume.restore_state(Autopilot::Slice.new(issue: 60, state: "in-progress"))

    refute @shell.ran?(/gh issue edit/)
  end
end

# The case review round 1 found, in real git: the developer's own checkout has
# feature/foo checked out, so the autopilot worktree cannot check it out. git
# runs for real; gh is faked.
class AutopilotResumeRealGitTest < Minitest::Test
  include AutopilotFixtures

  LOG = "docs/plans/2026-10-02-foo-autopilot.md"

  # Real git, fake gh.
  class SplitShell
    def initialize(gh) = (@gh = gh) && (@real = Autopilot::Shell.new)
    def run(*cmd, **options) = cmd.first == "git" ? @real.run(*cmd, **options) : @gh.run(*cmd, **options)
  end

  def git(dir, *args)
    out, status = Open3.capture2e("git", *args, chdir: dir)
    raise "git #{args.join(' ')}: #{out}" unless status.success?

    out.strip
  end

  def setup
    # Hermetic: the developer's global git config (signing, hooks) must not
    # reach these commits.
    @global = ENV.fetch("GIT_CONFIG_GLOBAL", nil)
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    @tmp = Dir.mktmpdir
    remote = File.join(@tmp, "remote.git")
    main = File.join(@tmp, "main")
    @worktree = File.join(@tmp, "main-autopilot-foo")
    git(@tmp, "init", "-q", "--bare", "-b", "main", remote)
    git(@tmp, "clone", "-q", remote, main)
    git(main, "config", "user.email", "t@t")
    git(main, "config", "user.name", "t")
    FileUtils.mkdir_p(File.join(main, "docs/plans"))
    File.write(File.join(main, "docs/plans/2026-10-02-foo-design.md"),
               "**Feature branch:** feature/foo\n\n**Autopilot:** on — log: #{LOG}\n")
    File.write(File.join(main, LOG), "# log\n\n## Halts and pauses\n\n## Metrics\n")
    git(main, "add", "-A")
    git(main, "commit", "-qm", "base")
    git(main, "checkout", "-qb", "feature/foo")
    git(main, "push", "-q", "-u", "origin", "main", "feature/foo")
    # The developer's checkout holds feature/foo; the autopilot worktree is on a slice branch.
    git(main, "worktree", "add", "-q", "-b", "feat/60/storage", @worktree, "feature/foo")

    gh = FakeShell.new
    gh.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => SLICES } ]))
    halt = "#### HALT · `halt` · /task_plan 60: no task file\n- **Where:** bin/autopilot on `feature/foo` at abc\n"
    gh.on(/gh issue view 60 .*--json comments/, JSON.generate("comments" => [ { "body" => "#{halt}\n#{Autopilot::MARKER}" } ]))
    shell = SplitShell.new(gh)
    @resume = Autopilot::Resume.new(feature: Autopilot::Feature.new("foo", shell: shell, root: @worktree),
                                    shell: shell, worktree: @worktree)
    @remote = remote
  end

  def teardown
    FileUtils.remove_entry(@tmp)
    @global ? ENV["GIT_CONFIG_GLOBAL"] = @global : ENV.delete("GIT_CONFIG_GLOBAL")
  end

  def test_copies_onto_the_remote_feature_branch_while_another_checkout_holds_it
    assert_equal 1, @resume.copy_halts

    on_remote = git(@tmp, "--git-dir", @remote, "show", "feature/foo:#{LOG}")
    assert_includes on_remote, "#### HALT · `halt` · /task_plan 60: no task file"
    assert_equal "feat/60/storage", git(@worktree, "branch", "--show-current")
    assert_equal "", git(@worktree, "status", "--porcelain")
    refute_includes File.read(File.join(@worktree, LOG)), "#### HALT", "the slice branch's log is untouched"
    assert_equal 0, @resume.copy_halts, "already on the feature branch: not copied twice"
  end

  # Landing and finishing work the feature branch the same way. A change that
  # fails partway leaves nothing behind: the remote untouched, the worktree
  # back on its branch and clean.
  def test_a_failed_change_leaves_the_remote_and_the_worktree_as_they_were
    branch = Autopilot::FeatureBranch.new(feature: Autopilot::Feature.new("foo", shell: nil, root: @worktree),
                                          shell: Autopilot::Shell.new, worktree: @worktree)
    before = git(@tmp, "--git-dir", @remote, "rev-parse", "feature/foo")

    assert_raises(RuntimeError) do
      branch.change do |b|
        File.write(File.join(@worktree, LOG), "edited\n")
        b.commit([ LOG ], "first")
        File.write(File.join(@worktree, LOG), "edited again\n")
        raise "the step after the commit failed"
      end
    end

    assert_equal before, git(@tmp, "--git-dir", @remote, "rev-parse", "feature/foo")
    assert_equal "feat/60/storage", git(@worktree, "branch", "--show-current")
    assert_equal "", git(@worktree, "status", "--porcelain")

    branch.change { |b| File.write(File.join(@worktree, LOG), "kept\n") && b.commit([ LOG ], "kept") }
    assert_equal "kept", git(@tmp, "--git-dir", @remote, "show", "feature/foo:#{LOG}")
  end
end

# The two tiers beside labels (docs/system/autopilot-steps.md, Tracker
# tiers): reading a slice's state, the resume check, restoring a cleared
# slice, and where HALT entries are found. Marking Blocked is in
# AutopilotRunTest, through a real halt.
class AutopilotTrackerTiersTest < Minitest::Test
  include AutopilotFixtures

  LOG = "docs/plans/2026-10-02-foo-autopilot.md"

  def setup
    @root = design_repo
    File.write(File.join(@root, LOG), "# Foo — autopilot log\n\n## Halts and pauses\n\n## Metrics\n")
    @shell = FakeShell.new
    @shell.on("git branch --show-current", "feature/foo\n")
    @shell.on(/gh pr list .*--base feature\/foo --state merged/, "[]")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def feature = @feature ||= Autopilot::Feature.new("foo", shell: @shell, root: @root)
  def resume = Autopilot::Resume.new(feature: feature, shell: @shell, worktree: @root)
  def slices_pr(body) = @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => body } ]))

  # github-projects

  def board!
    tier!("github-projects")
    slices_pr(SLICES)
    @shell.on(/^gh api graphql -f query=\{ repository\(owner: "acme", name: "shop"\) \{ issue\(number: 60\)/, board_items_json("PVTI_60"))
  end

  def test_board_a_blocked_card_stops_the_run_at_its_slice
    board!
    @shell.on("gh issue view 60 --repo acme/shop --json body,projectItems,state", board_issue_json("#47 first.", option: "opt-blocked"))

    slice = feature.next_slice

    assert_equal 60, slice.issue
    assert slice.blocked
  end

  def test_board_reads_the_card_on_this_apps_board_by_option_id
    board!
    @shell.on("gh issue view 60 --repo acme/shop --json body,projectItems,state", board_issue_json("#47 first.", option: "opt-doing"))

    assert_equal "in-progress", feature.tracker.state(60)
    refute feature.next_slice.blocked, "the other board's Done card does not count"
  end

  # A board whose option IDs were re-created since /workflow_setup ran still
  # names its columns the way WORKFLOW.md does.
  def test_board_falls_back_to_the_status_name
    board!
    @shell.on("gh issue view 60 --repo acme/shop --json body,projectItems,state",
              board_issue_json("", option: "opt-unknown", name: "Up for Review"))

    assert_equal "up-for-review", feature.tracker.state(60)
  end

  def test_board_dependencies_come_from_the_issue_body
    board!
    @shell.on("gh issue view 60 --repo acme/shop --json body,projectItems,state", board_issue_json("#48 first.", option: "opt-todo"))
    @shell.on("gh issue view 48 --repo acme/shop --json body,projectItems,state", board_issue_json("", option: "opt-todo"))

    assert_equal 48, feature.next_slice.issue
  end

  # Clearing Blocked on a board means picking another Status; the driver puts
  # the card where the slice really is.
  def test_board_restores_a_cleared_card_to_where_the_slice_is
    board!
    @shell.on(%r{git ls-remote --heads origin refs/heads/feat/60/\*}, "abc\trefs/heads/feat/60/storage\n")
    @shell.on(%r{gh pr list --repo acme/shop --head feat/60/storage --state open}, JSON.generate([ { "number" => 71 } ]))

    resume.restore_state(Autopilot::Slice.new(issue: 60, state: "todo"))

    assert @shell.ran?("gh project item-edit --project-id PVT_1 --id PVTI_60 --field-id PVTSSF_1 --single-select-option-id opt-review")
  end

  def test_board_leaves_a_card_already_in_the_right_column
    board!
    resume.restore_state(Autopilot::Slice.new(issue: 60, state: "todo"))

    refute @shell.ran?(/gh project item-edit/)
  end

  def test_board_an_issue_missing_from_the_board_is_not_written
    board!
    @shell.on(/^gh api graphql -f query=\{ repository/, JSON.generate("data" => { "repository" => { "issue" => { "projectItems" => { "nodes" => [] } } } }))

    refute feature.tracker.set(60, "blocked")
    refute @shell.ran?(/gh project item-edit/)
  end

  def test_board_halts_are_read_from_the_issue
    board!
    halt = "#### HALT · `halt` · stuck\n- **Where:** bin/autopilot on `feat/60/x` at abc\n"
    @shell.on(/gh issue view \d+ --repo acme\/shop --json comments/, JSON.generate("comments" => []))
    @shell.on("gh issue view 60 --repo acme/shop --json comments", JSON.generate("comments" => [ { "body" => "#{halt}\n#{Autopilot::MARKER}" } ]))

    assert_equal 1, resume.copy_halts
  end

  def test_board_probe_names_a_board_it_cannot_read
    board!
    @shell.on(/^gh api graphql -f query=\{ node\(id: "PVT_1"\)/, JSON.generate("data" => { "node" => nil }))

    assert_match(/cannot read the board PVT_1 \(github-projects\)/, feature.tracker.probe)

    @shell.on(/^gh api graphql -f query=\{ node\(id: "PVT_1"\)/, JSON.generate("data" => { "node" => { "id" => "PVT_1" } }))
    assert_nil feature.tracker.probe
  end

  # beads

  def beads!
    tier!("beads")
    slices_pr(BEAD_SLICES)
  end

  def test_beads_slices_are_bead_ids
    beads!

    assert_equal %w[bd-a1 bd-b2 bd-c3], feature.slices.map(&:issue)
    assert_equal %w[bd-a1], feature.slices.select(&:done).map(&:issue)
  end

  # `bd init --prefix acme` names beads `acme-<hash>` (docs/sop/beads-setup.md);
  # the driver reads them as the thread ID, as branches and task files name them.
  def test_beads_a_list_in_the_databases_own_prefix_reads_as_thread_ids
    tier!("beads")
    slices_pr("## Slices\n- [x] acme-a1 — Cart store (PR #57)\n- [ ] acme-b2 — Checkout\n- [ ] my-app-c3 — Receipts\n")
    @shell.on("bd show b2 --json", bead_json("b2", status: "open", blocked_by: %w[a1]))

    assert_equal %w[bd-a1 bd-b2 bd-c3], feature.slices.map(&:issue)
    assert_equal "bd-b2", feature.next_slice.issue

    feature.tick("bd-b2", 71)
    body = File.read(@shell.calls.find { |c| c[:line].start_with?("gh pr edit 53") }[:line].split.last)
    assert_includes body, "- [x] acme-b2 — Checkout (PR #71)\n"
  end

  def test_beads_a_blocked_bead_stops_the_run_at_its_slice
    beads!
    @shell.on("bd show b2 --json", bead_json("b2", status: "blocked", blocked_by: %w[a1]))

    slice = feature.next_slice

    assert_equal "bd-b2", slice.issue
    assert slice.blocked
  end

  # bd's blocks edges are the dependencies; the epic's parent-child edge is not.
  def test_beads_dependencies_come_from_blocks_edges
    beads!
    @shell.on("bd show b2 --json", bead_json("b2", status: "open", blocked_by: %w[c3]))
    @shell.on("bd show c3 --json", bead_json("c3", status: "open", blocked_by: %w[a1]))

    assert_equal "bd-c3", feature.next_slice.issue
  end

  def test_beads_state_reads_the_up_for_review_label_over_the_status
    beads!
    @shell.on("bd show b2 --json", bead_json("b2", status: "in_progress", labels: [ "lifecycle:up_for_review" ]))
    assert_equal "up-for-review", feature.tracker.state("bd-b2")

    @shell.on("bd show b2 --json", bead_json("b2", status: "in_progress"))
    assert_equal "in-progress", feature.tracker.state("bd-b2")

    @shell.on("bd show b2 --json", bead_json("b2", status: "open"))
    assert_equal "todo", feature.tracker.state("bd-b2")
  end

  # Clearing Blocked is `bd update --status open`, which reads as Todo; the
  # driver moves the bead on to where the slice really is.
  def test_beads_restores_a_cleared_bead_with_a_pushed_branch_to_in_progress
    beads!
    @shell.on(%r{git ls-remote --heads origin refs/heads/feat/bd-b2/\*}, "abc\trefs/heads/feat/bd-b2/checkout\n")
    @shell.on(%r{gh pr list --repo acme/shop --head feat/bd-b2/checkout --state open}, "[]")

    resume.restore_state(Autopilot::Slice.new(issue: "bd-b2", state: "todo"))

    assert @shell.ran?("bd update b2 --status in_progress")
    assert @shell.ran?("bd label remove b2 lifecycle:up_for_review")
  end

  def test_beads_restores_a_slice_under_review_with_set_state
    beads!
    @shell.on(/gh pr list .*--base feature\/foo --state merged/, JSON.generate([ { "number" => 72, "headRefName" => "feat/bd-b2/checkout" } ]))

    resume.restore_state(Autopilot::Slice.new(issue: "bd-b2", state: "todo"))

    assert @shell.ran?("bd set-state b2 lifecycle=up_for_review")
    refute @shell.ran?(/bd update/)
  end

  def test_beads_a_closed_bead_is_left_alone
    beads!
    resume.restore_state(Autopilot::Slice.new(issue: "bd-b2", state: "done"))

    refute @shell.ran?(/^bd /)
  end

  # No GitHub issue: entries are on the feature PR, and read once for all.
  def test_beads_halts_are_read_from_the_feature_pr
    beads!
    halt = "#### HALT · `halt` · stuck\n- **Where:** bin/autopilot on `feat/bd-b2/x` at abc\n"
    @shell.on("gh pr view 53 --repo acme/shop --json comments",
              JSON.generate("comments" => [ { "body" => "#{halt}\n#{Autopilot::MARKER}" }, { "body" => "Landed.\n\n#{Autopilot::MARKER}" } ]))

    assert_equal 1, resume.copy_halts
    assert_match(/#### HALT · `halt` · stuck/, File.read(File.join(@root, LOG)))
    refute @shell.ran?(/^gh issue /)
  end

  def test_beads_a_landed_slice_is_ticked_without_a_closes_line
    beads!

    feature.tick("bd-b2", 71)

    body = File.read(@shell.calls.find { |c| c[:line].start_with?("gh pr edit 53") }[:line].split.last)
    assert_includes body, "- [x] bd-b2 — Checkout (PR #71)\n"
    refute_includes body, "Closes"
  end

  def test_beads_the_merged_pr_is_found_by_the_bead_branch
    beads!
    @shell.on(/gh pr list .*--base feature\/foo --state merged/,
              JSON.generate([ { "number" => 70, "headRefName" => "feat/bd-b22/other" }, { "number" => 72, "headRefName" => "feat/bd-b2/checkout" } ]))

    assert_equal 72, feature.merged_pr("bd-b2")["number"]
  end

  def test_beads_the_log_names_the_slice_by_its_bead_id
    text = "## Slices\n\n## Metrics\n\n#### Dbd-b2-1 · `choice` · Card or invoice first?\n- **Reversible:** one-way\n"

    out = Autopilot::Log.slice_section(text, issue: "bd-b2", title: "Checkout", pr: 71, sha: "5bc96eb", row: [ 1, 2, 1, 0, 0, "1m 0s", "$1.00" ])

    assert_match(/^### bd-b2 — Checkout \(PR #71, merged 5bc96eb\)\n/, out)
    assert_match(/#### Decisions\n\n#### Dbd-b2-1 · `choice`/, out)
    assert_match(/one-way\*\* · Dbd-b2-1/, Autopilot::Log.read_this_first("## Read this first\n\n#{out}"))
  end

  def test_beads_probe_names_a_database_it_cannot_read
    beads!
    @shell.on("bd list --json --limit 1", "Error: no beads database found", ok: false)

    assert_match(/bd cannot read the beads database \(beads\): Error: no beads database found/, feature.tracker.probe)
  end
end

class AutopilotRetryingShellTest < Minitest::Test
  def setup
    @fake = FakeShell.new
    @slept = []
    @shell = Autopilot::RetryingShell.new(@fake, sleep: ->(seconds) { @slept << seconds })
  end

  # One failed `gh pr view` ended #105's run before review pass 2.
  def test_a_gh_read_that_fails_once_is_tried_again
    replies = [ false, true ]
    @fake.on(/gh pr view/) { Autopilot::Shell::Result.new("abc1234", replies.shift, false) }

    result = @shell.run("gh", "pr", "view", "130", "--json", "headRefOid")

    assert result.ok
    assert_equal "abc1234", result.out
    assert_equal [ Autopilot::RetryingShell::DELAYS.first ], @slept
  end

  def test_a_gh_read_that_keeps_failing_returns_the_last_failure
    @fake.on(/gh issue view/, "boom", ok: false)

    refute @shell.run("gh", "issue", "view", "105").ok
    assert_equal Autopilot::RetryingShell::DELAYS.size + 1, @fake.calls.size
    assert_equal Autopilot::RetryingShell::DELAYS, @slept
  end

  def test_pr_list_and_api_gets_are_reads
    @fake.on(/gh/, ok: false)

    @shell.run("gh", "pr", "list", "--head", "x")
    @shell.run("gh", "api", "--paginate", "repos/o/r/pulls/1/reviews")

    assert_equal 2 * (Autopilot::RetryingShell::DELAYS.size + 1), @fake.calls.size
  end

  # A write that failed may still have landed: a second try could post twice.
  def test_gh_writes_are_not_retried
    @fake.on(/gh/, ok: false)

    @shell.run("gh", "pr", "comment", "53", "--body", "x")
    @shell.run("gh", "pr", "merge", "130", "--squash")
    @shell.run("gh", "api", "-X", "POST", "repos/o/r/issues/1/comments")
    @shell.run("gh", "api", "repos/o/r/issues/1/comments", "-f", "body=x")

    assert_equal 4, @fake.calls.size
    assert_empty @slept
  end

  # `gh pr checks` exits non-zero for pending or red checks: that is an answer.
  def test_pr_checks_and_non_gh_commands_are_not_retried
    @fake.on(//, ok: false)

    @shell.run("gh", "pr", "checks", "130", "--json", "name,state")
    @shell.run("git", "fetch")

    assert_equal 2, @fake.calls.size
  end

  def test_the_rest_of_the_shell_passes_through
    @fake.alive!(7)

    assert @shell.alive?(7)
    @shell.kill_group(7)
    assert @fake.ran?("kill_group 7")
  end
end

class AutopilotShellAliveTest < Minitest::Test
  # A pid written by a previous run is not our child. waitpid raises ECHILD
  # for it, and that must not read as "dead", or a second bin/dev starts on
  # the same port.
  def test_a_process_that_is_not_our_child_is_alive
    reader, writer = IO.pipe
    outer = Process.spawn("sh", "-c", "sleep 5 >/dev/null 2>&1 & echo $!", out: writer)
    writer.close
    grandchild = reader.read.to_i
    Process.wait(outer)

    assert Autopilot::Shell.new.alive?(grandchild)
  ensure
    Process.kill("KILL", grandchild) if grandchild&.positive?
  end

  def test_a_finished_child_is_not_alive
    pid = Process.spawn("true")
    sleep 0.2

    refute Autopilot::Shell.new.alive?(pid)
  end
end

class AutopilotServerTest < Minitest::Test
  def setup
    @worktree = Dir.mktmpdir
    @shell = FakeShell.new
    @server = Autopilot::Server.new(worktree: @worktree, shell: @shell)
  end

  def teardown
    FileUtils.remove_entry(@worktree)
  end

  def test_starts_bin_dev_on_the_autopilot_port_with_its_databases
    @server.start

    call = @shell.calls.find { |c| c[:line] == "spawn bin/dev" }
    assert_equal({ "PORT" => "3100", "DB_SUFFIX" => "_autopilot" }, call[:env])
    assert_equal @worktree, call[:chdir]
    assert_equal "4242", File.read(File.join(@worktree, "tmp/autopilot/dev.pid")).strip
  end

  def test_reuses_a_server_that_is_still_running
    FileUtils.mkdir_p(File.join(@worktree, "tmp/autopilot"))
    File.write(File.join(@worktree, "tmp/autopilot/dev.pid"), "777")
    @shell.alive!(777)

    @server.start

    refute @shell.ran?(/^spawn/)
  end

  def test_stop_kills_the_group_and_forgets_the_pid
    @server.start
    @server.stop

    assert @shell.ran?("kill_group 4242")
    refute File.exist?(File.join(@worktree, "tmp/autopilot/dev.pid"))
  end
end

# Stands in for Autopilot::Run: #slice does whatever the block does, and
# #finalize is recorded.
class FakeRun
  attr_reader :finalized

  def initialize(&block) = (@block = block) && (@finalized = [])
  def slice(issue) = @block.call(issue)
  def finalize(issue, slices) = @finalized << [ issue, slices ]
end

class AutopilotCLITest < Minitest::Test
  include AutopilotFixtures

  # A main checkout and its autopilot worktree, side by side, as --setup
  # leaves them.
  def setup
    @parent = Dir.mktmpdir
    @root = File.join(@parent, "shop")
    @worktree = File.join(@parent, "shop-autopilot-foo")
    FileUtils.mkdir_p(File.join(@root, ".git"))
    FileUtils.cp_r(design_repo, @worktree)
    FileUtils.mkdir_p(File.join(@worktree, ".claude"))
    File.write(File.join(@worktree, ".claude/autopilot-allowed-tools.txt"), "Read\n")
    FileUtils.cp(CONFIG, File.join(@worktree, ".claude/workflow.config.md"))
    FileUtils.cp(File.expand_path("../../.claude/settings.json", __dir__), File.join(@worktree, ".claude/settings.json"))
    FileUtils.mkdir_p(File.join(@worktree, "bin/hooks"))
    FileUtils.cp(File.expand_path("../../bin/hooks/autopilot_guard", __dir__), File.join(@worktree, "bin/hooks/autopilot_guard"))
    File.write(File.join(@worktree, "docs/plans/2026-10-02-foo-autopilot.md"), "# log\n\n## Halts and pauses\n")
    @shell = FakeShell.new
    @shell.on("git rev-parse --path-format=absolute --git-common-dir", "#{@root}/.git\n")
    @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => SLICES } ]))
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state", issue_json("#47 first."))
    @shell.on(/gh issue view \d+ .*--json comments/, JSON.generate("comments" => []))
    @shell.on(/gh pr list .*--state merged/, "[]")
    @shell.on("git branch --show-current", "feature/foo\n")
    @out = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@parent)
  end

  def cli(*argv, **options) = Autopilot::CLI.new(argv, shell: @shell, out: @out, desktop: false, **options)

  MUTATING = /^(claude |spawn |gh (issue|pr) (edit|comment|create|merge|ready)|git (checkout|commit|push|pull|worktree|merge)|bundle|bin\/rails)/

  def test_dry_run_prints_the_plan_and_changes_nothing
    assert_equal 0, cli("foo", "--dry-run").call

    assert_match(/Next slice: #60/, @out.string)
    assert_match(%r{claude -p /task_plan 60 --permission-mode dontAsk}, @out.string)
    assert_empty @shell.lines.grep(MUTATING), "dry run ran: #{@shell.lines.grep(MUTATING).inspect}"
  end

  def write_state(data)
    FileUtils.mkdir_p(File.join(@worktree, "tmp/autopilot"))
    File.write(File.join(@worktree, "tmp/autopilot/foo.json"), JSON.generate(data))
  end

  def tokens(read:, write_1h:, input: 0) =
    { "input" => input, "output" => 10, "cache_read" => read, "cache_write_5m" => 0, "cache_write_1h" => write_1h }

  # Repeatable measurement: the summary reads the state file alone, so it runs
  # mid-run, after a run, or on a copied state file.
  def test_usage_summarises_each_step_from_the_state_file
    write_state(
      "60" => { "usage" => [
        { "step" => "/implement 60", "kind" => "ok", "usd" => 4.0, "seconds" => 600, "tokens" => tokens(read: 900, write_1h: 100), "turns" => 40 },
        { "step" => "/pr_comment_resolver 70", "kind" => "ok", "usd" => 8.0, "seconds" => 300, "tokens" => tokens(read: 100, write_1h: 900), "turns" => 9 },
        { "step" => "CI wait, PR #70", "kind" => "driver", "at" => "2026-10-02T10:00:00-07:00", "seconds" => 60 }
      ] },
      "61" => { "usage" => [
        { "step" => "/implement 61", "kind" => "usage_limit", "usd" => 2.0, "seconds" => 200, "tokens" => tokens(read: 700, write_1h: 300) }
      ] }
    )

    assert_equal 0, cli("foo", "--usage").call

    implement = @out.string.lines.find { |l| l.start_with?("/implement") }
    resolver = @out.string.lines.find { |l| l.start_with?("/pr_comment_resolver") }
    assert_match(/\b2\s+\$6\.00\s+\$3\.00\b/, implement, "two runs, $6 total, $3 each")
    assert_match(/\b80%/, implement, "1,600 read of 2,000 cached tokens")
    assert_match(/\b10%/, resolver)
    assert_match(/^total\s+3\s+\$14\.00/, @out.string)
    refute_match(/CI wait/, @out.string, "driver rows spend no tokens")
    assert_empty @shell.lines.grep(MUTATING)
    refute_includes @shell.lines, "gh auth status", "a summary needs no preflight"
  end

  # Rows from before token capture still count toward cost and runs.
  def test_usage_counts_rows_without_tokens_toward_cost_only
    write_state("60" => { "usage" => [ { "step" => "/pr_review 70", "kind" => "ok", "usd" => 1.0, "seconds" => 60 } ] })

    assert_equal 0, cli("foo", "--usage").call

    assert_match(/^\/pr_review\s+1\s+\$1\.00\s+\$1\.00\s+1\s+—/, @out.string)
  end

  def test_usage_shows_turns_ending_context_subagents_and_denials
    write_state("60" => { "usage" => [
      { "step" => "/implement 60", "kind" => "ok", "usd" => 4.0, "seconds" => 600, "turns" => 200, "context_end" => 90_000, "subagents" => 2, "denials" => 1 },
      { "step" => "/implement 61", "kind" => "ok", "usd" => 2.0, "seconds" => 600, "turns" => 100, "context_end" => 50_000, "subagents" => 1, "denials" => 0 }
    ] })

    cli("foo", "--usage").call

    header = @out.string.lines.find { |l| l.start_with?("step") }
    assert_match(/turns\s+ctx end\s+agents\s+denied$/, header.rstrip)
    assert_match(/150\s+70\.0k\s+3\s+1$/, @out.string.lines.find { |l| l.start_with?("/implement") }.rstrip)
  end

  def test_usage_shows_each_resolver_variant_on_its_own_line
    write_state("60" => { "usage" => [
      { "step" => "/pr_comment_resolver 70", "kind" => "ok", "usd" => 8.0, "seconds" => 300, "variant" => "resume" },
      { "step" => "/pr_comment_resolver 71", "kind" => "ok", "usd" => 2.0, "seconds" => 300, "variant" => "fresh" }
    ] })

    cli("foo", "--usage").call

    assert_match(%r{^/pr_comment_resolver \(resume\)\s+1\s+\$8\.00}, @out.string)
    assert_match(%r{^/pr_comment_resolver \(fresh\)\s+1\s+\$2\.00}, @out.string)
  end

  def test_resolver_flag_reaches_the_run
    parts = nil
    cli("foo", "--resolver", "fresh", run_factory: ->(**given) { (parts = given) && FakeRun.new { nil } }).call

    assert_equal :fresh, parts[:resolver]
  end

  # Codex and Cursor have their own permission and hook models, unverified:
  # a stub that says so beats an adapter that runs without the guard.
  %w[codex cursor].each do |name|
    define_method("test_cli_#{name}_fails_clearly_and_runs_nothing") do
      assert_equal 1, cli("foo", "--cli", name).call

      assert_match(/no #{name} adapter: it drives Claude Code only/, @out.string)
      assert_match(/a hook before every tool call that can deny it/, @out.string)
      assert_empty @shell.lines, "nothing is checked or run"
    end
  end

  def test_cli_claude_is_the_default_and_runs
    assert_equal 0, cli("foo", "--cli", "claude", "--dry-run").call
    assert_match(/Next slice: #60/, @out.string)
  end

  def test_an_unknown_cli_is_a_usage_error
    assert_equal 1, cli("foo", "--cli", "gemini").call
    assert_match(/usage: bin\/autopilot/, @out.string)
  end

  def test_an_unknown_resolver_mode_is_a_usage_error
    assert_equal 1, cli("foo", "--resolver", "sideways").call
    assert_match(/usage: bin\/autopilot/, @out.string)
  end

  def test_usage_without_a_state_file_says_so
    assert_equal 1, cli("foo", "--usage").call

    assert_match(%r{no state at .*tmp/autopilot/foo\.json}, @out.string)
  end

  def test_preflight_names_every_problem_and_runs_nothing
    @shell.on("gh auth status", "not logged in", ok: false)
    @shell.on("git status --porcelain", " M Gemfile\n")
    File.write(File.join(@worktree, "docs/plans/2026-10-02-foo-design.md"), "**Feature branch:** feature/foo\n")

    assert_equal 1, cli("foo").call

    assert_match(/no `\*\*Autopilot:\*\* on`/, @out.string)
    assert_match(/uncommitted changes/, @out.string)
    assert_match(/gh is not signed in/, @out.string)
    assert_empty @shell.lines.grep(MUTATING)
  end

  def test_preflight_refuses_a_run_without_the_workflow_config
    FileUtils.rm(File.join(@worktree, ".claude/workflow.config.md"))

    assert_equal 1, cli("foo").call
    assert_match(/workflow\.config\.md has no `GITHUB_REPO` value/, @out.string)
    refute @shell.ran?(/^gh /), "no gh call without a repo to name"
  end

  # Read as "every slice landed", a list the tier cannot parse would finish
  # the feature, or crash on a draft PR. Preflight names it instead.
  def test_preflight_refuses_a_slices_list_it_cannot_read
    @shell.on(/gh pr list .*--head feature\/foo/,
              JSON.generate([ { "number" => 53, "body" => "## Slices\n- [ ] acme-a3f2 — x\n", "isDraft" => true } ]))

    assert_equal 1, cli("foo").call
    assert_match(/feature PR #53 lists no slice rows this tier can read/, @out.string)
    assert_empty @shell.lines.grep(MUTATING)
  end

  # A checklist item in the feature PR is not a slice on a GitHub tier.
  def test_a_checklist_bullet_is_not_read_as_a_slice
    @shell.on(/gh pr list .*--head feature\/foo/,
              JSON.generate([ { "number" => 53, "body" => "## Slices\n- [ ] #60 — a\n\n## Before merge\n- [ ] re-run checks\n" } ]))

    assert_equal [ 60 ], Autopilot::Feature.new("foo", shell: @shell, root: @worktree).slices.map(&:issue)
  end

  def test_preflight_refuses_a_tier_it_cannot_read
    File.write(File.join(@worktree, ".claude/workflow.config.md"),
               File.read(CONFIG).sub("| `TRACKER` | `labels` |", "| `TRACKER` | `beads` |"))
    @shell.on("bd list --json --limit 1", "Error: no beads database found", ok: false)

    assert_equal 1, cli("foo").call
    assert_match(/bd cannot read the beads database \(beads\)/, @out.string)
    assert_empty @shell.lines.grep(MUTATING)
  end

  def test_a_run_without_the_guard_wired_is_not_started
    settings = File.join(@worktree, ".claude/settings.json")
    File.write(settings, JSON.generate(JSON.parse(File.read(settings)).tap { |s| s["hooks"].delete("PreToolUse") }))

    assert_equal 1, cli("foo").call
    assert_match(/the guard is not wired: .*autopilot_guard under PreToolUse/, @out.string)
    assert_empty @shell.lines.grep(MUTATING)
  end

  # A bare `on` is consent (the spec accepts it), but the run has nowhere to
  # write. Preflight says so instead of the run crashing on a nil path.
  def test_consent_without_a_log_path_fails_preflight_by_name
    File.write(File.join(@worktree, "docs/plans/2026-10-02-foo-design.md"),
               "**Feature branch:** feature/foo\n\n**Autopilot:** on\n")

    assert_equal 1, cli("foo").call
    assert_match(/names no log/, @out.string)
  end

  def test_without_a_worktree_it_says_to_run_setup
    FileUtils.remove_entry(@worktree)

    assert_equal 1, cli("foo").call
    assert_match(/bin\/autopilot foo --setup/, @out.string)
  end

  def test_setup_makes_the_worktree_once_and_prepares_both_databases
    FileUtils.remove_entry(@worktree)
    @shell.on(/^git worktree add/) do
      FileUtils.mkdir_p(@worktree)
      Autopilot::Shell::Result.new("", true, false)
    end

    assert_equal 0, cli("foo", "--setup").call
    assert @shell.ran?("git worktree add #{@worktree} feature/foo")
    dev = @shell.calls.find { |c| c[:line] == "bin/rails db:prepare" }
    assert_equal({ "DB_SUFFIX" => "_autopilot" }, dev[:env], "development is prepared, and seeded for walkthroughs")
    # db:prepare seeds a database it creates; seeded rows in a test database
    # outlive every test. The test databases get the schema only.
    test = @shell.calls.find { |c| c[:line] == "bin/rails db:test:prepare" }
    assert_equal({ "DB_SUFFIX" => "_autopilot" }, test && test[:env])
    refute @shell.calls.any? { |c| c[:env].to_h["RAILS_ENV"] == "test" && c[:line] == "bin/rails db:prepare" }

    @shell.calls.clear
    cli("foo", "--setup").call
    refute @shell.ran?(/^git worktree add/), "setup is idempotent"
  end

  def test_a_feature_already_finished_ends_cleanly
    @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => "- [x] #1 — a\n", "isDraft" => false } ]))

    assert_equal 0, cli("foo").call
    assert_match(/ready for review\. Nothing to do/, @out.string)
    refute @shell.ran?(/^spawn/), "nothing to run, no server"
  end

  # The feature PR as the fake run leaves it: each landed slice ticked.
  def slices_pr(*ticked)
    body = [ 60, 61 ].map { |n| "- [#{ticked.include?(n) ? 'x' : ' '}] ##{n} — slice #{n}\n" }.join
    @shell.on(/gh pr list .*--head feature\/foo/, JSON.generate([ { "number" => 53, "body" => "## Slices\n#{body}", "isDraft" => true } ]))
  end

  def test_runs_slice_after_slice_then_finishes_the_feature_once
    slices_pr
    @shell.on("gh issue view 61 --repo acme/shop --json body,labels,state", issue_json("#60 first."))
    landed = []
    fake = FakeRun.new { |issue| (landed << issue) && slices_pr(*landed) }

    assert_equal 0, cli("foo", run_factory: ->(**) { fake }).call

    assert_equal [ 60, 61 ], landed
    assert_equal [ [ 61, [ 60, 61 ] ] ], fake.finalized
    assert_match(/Finished: feature PR #53 is ready for review/, @out.string)
  end

  def test_a_blocked_slice_after_one_lands_stops_the_run_unfinished
    slices_pr
    @shell.on("gh issue view 61 --repo acme/shop --json body,labels,state",
              issue_json("#60 first.", labels: [ "status:blocked" ]))
    fake = FakeRun.new { |issue| slices_pr(issue) }

    assert_equal 2, cli("foo", run_factory: ->(**) { fake }).call

    assert_match(/#61 is blocked/, @out.string)
    assert_empty fake.finalized
  end

  def test_a_feature_pr_gone_mid_run_stops_with_a_notice_not_a_crash
    slices_pr
    @shell.on("gh issue view 61 --repo acme/shop --json body,labels,state", issue_json("#60 first."))
    fake = FakeRun.new { |_issue| @shell.on(/gh pr list .*--head feature\/foo/, "HTTP 502", ok: false) }

    assert_equal 2, cli("foo", run_factory: ->(**) { fake }).call

    assert_match(/Stopped on feature\/foo: cannot read the open feature PR for feature\/foo/, @out.string)
    assert_empty fake.finalized
  end

  # A slice that "lands" but stays unticked would otherwise run forever.
  def test_a_slice_still_open_after_landing_stops_rather_than_looping
    slices_pr
    fake = FakeRun.new { |_issue| nil }

    assert_equal 2, cli("foo", run_factory: ->(**) { fake }).call
    assert_match(/#60 is still open after it landed/, @out.string)
  end

  # A halt in finalize lands on the last slice, which is already ticked. The
  # rerun must copy its entry and wait for the developer, not finish anyway.
  def test_a_halt_while_finishing_holds_the_rerun_and_reaches_the_log
    slices_pr(60, 61)
    @shell.on("gh issue view 61 --repo acme/shop --json body,labels,state",
              issue_json("", labels: [ "status:blocked" ]))
    halt = "#### HALT · `halt` · /update_docs: still Draft\n- **Where:** bin/autopilot on a detached HEAD at abc\n"
    @shell.on("gh issue view 61 --repo acme/shop --json comments",
              JSON.generate("comments" => [ { "body" => "#{halt}\n#{Autopilot::MARKER}" } ]))
    fake = FakeRun.new { |_issue| flunk "every slice has landed" }

    assert_equal 2, cli("foo", run_factory: ->(**) { fake }).call

    assert_match(/#61 is blocked/, @out.string)
    assert_empty fake.finalized
    assert @shell.ran?(/^git commit -m Copy 1 HALT entry/), "the entry on the ticked slice is copied into the log"
  end

  def test_a_cleared_halt_while_finishing_gives_the_last_slice_its_label_back
    slices_pr(60, 61)
    @shell.on("gh issue view 61 --repo acme/shop --json body,labels,state", issue_json("", labels: []))
    @shell.on(/gh pr list .*--state merged/, JSON.generate([ { "number" => 72, "headRefName" => "feat/61/b" } ]))
    fake = FakeRun.new { |_issue| flunk "every slice has landed" }

    assert_equal 0, cli("foo", run_factory: ->(**) { fake }).call

    assert @shell.ran?(/gh issue edit 61 .*--add-label status:up-for-review/)
    assert_equal 1, fake.finalized.size
  end

  def test_open_slices_that_cannot_start_stop_without_finishing
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state", issue_json("#99 first."))
    @shell.on(/gh pr list .*--head feature\/foo/,
              JSON.generate([ { "number" => 53, "body" => "- [ ] #60 — a\n- [ ] #99 — b\n", "isDraft" => true } ]))
    @shell.on("gh issue view 99 --repo acme/shop --json body,labels,state", issue_json("#60 first."))
    fake = FakeRun.new { |_issue| flunk "nothing can start" }

    assert_equal 2, cli("foo", run_factory: ->(**) { fake }).call
    assert_match(/waits on a dependency/, @out.string)
    assert_empty fake.finalized
  end

  def test_a_blocked_slice_stops_the_run_and_says_why
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state",
              issue_json("#47 first.", labels: [ "status:blocked" ]))

    assert_equal 2, cli("foo").call
    assert_match(/#60 is blocked/, @out.string)
    refute @shell.ran?(/^spawn/), "a blocked slice starts no server"
  end

  def test_a_halt_exits_2_and_stops_the_server
    halting = ->(**) { FakeRun.new { raise Autopilot::Halted.new("G2", "over the bound", 60) } }

    assert_equal 2, cli("foo", run_factory: halting).call
    assert_match(/Halted on #60 \(gate G2\): over the bound/, @out.string)
    assert @shell.ran?("kill_group 4242")
  end

  def test_ctrl_c_aborts_with_130_and_still_stops_the_server
    interrupted = ->(**) { FakeRun.new { raise Interrupt } }

    assert_equal 130, cli("foo", run_factory: interrupted).call
    assert_match(/Aborted\. The step that was running is stopped/, @out.string)
    assert @shell.ran?("kill_group 4242")
  end

  # gh down, a PR gone: not a policy halt (no label changes), but the
  # developer still hears about it, and the server still stops.
  def test_an_infrastructure_error_stops_with_a_notice_and_exit_2
    failing = ->(**) { FakeRun.new { raise Autopilot::Error, "cannot read PR #70's head" } }

    assert_equal 2, cli("foo", run_factory: failing).call
    assert_match(/Stopped on #60: cannot read PR #70's head/, @out.string)
    assert @shell.ran?(/^gh pr comment 53 .*Stopped on #60/m)
    refute @shell.ran?(/gh issue edit 60 .*status:blocked/)
    assert @shell.ran?("kill_group 4242")
  end

  def test_a_cleared_slice_gets_its_label_back_before_it_runs
    @shell.on("gh issue view 60 --repo acme/shop --json body,labels,state", issue_json("#47 first.", labels: []))
    @shell.on("gh issue view 61 --repo acme/shop --json body,labels,state",
              issue_json("", labels: [ "status:in-progress" ]))
    slices_pr
    ran = []
    factory = ->(**) { FakeRun.new { |issue| (ran << issue) && slices_pr(*ran) } }

    assert_equal 0, cli("foo", run_factory: factory).call
    assert @shell.ran?(/gh issue edit 60 .*--add-label status:todo/)
    refute @shell.ran?(/gh issue edit 61/), "a slice with its status label keeps it"
    assert_equal [ 60, 61 ], ran
  end
end

# The driver's parts of the autopilot log, from a fixture written in the
# template's shape: #47 already landed, #48's entries appended at the end of
# the file by the commands, as they are before the driver files them.
class AutopilotLogTest < Minitest::Test
  FIXTURE = File.read(File.expand_path("fixtures/autopilot/log.md", __dir__))
  ROW = [ 420, 6, 1, 3, 0, "1h 5m", "$9.40" ].freeze

  def landed = Autopilot::Log.slice_section(FIXTURE, issue: 48, title: "Top-down format", pr: 71, sha: "5bc96eb", row: ROW)

  def section(text, heading)
    text[/^#{Regexp.escape(heading)}.*?(?=^### |^## |\z)/m]
  end

  def test_a_landed_slice_gets_its_section_after_the_last_one_with_its_entries_gathered
    text = landed
    mine = section(text, "### #48")

    assert mine, "no section for #48"
    assert text.index("### #47") < text.index("### #48"), "merge order"
    assert text.index("### #48") < text.index("## QA"), "inside ## Slices"
    assert_includes mine, "### #48 — Top-down format (PR #71, merged 5bc96eb)\n\n| Added |"
    assert_includes mine, "| 420 | 6 | 1 | 3 | 0 | 1h 5m | $9.40 |\n\n#### Decisions\n\n#### D48-1 ·"
    assert_equal 3, mine.scan(/^#### D48-/).size
    assert_equal 3, text.scan(/^#### D48-/).size, "moved, not copied"
    assert_match(/\| #47 \| `\/task_plan 47` .*\|\n\z/, text, "nothing left behind after the metrics table")
  end

  def test_landing_twice_changes_nothing
    assert_equal landed, Autopilot::Log.slice_section(landed, issue: 48, title: "Top-down format", pr: 71, sha: "5bc96eb", row: ROW)
  end

  # The commands may have written the heading themselves (the spec says they
  # append under `### #<issue>`); the driver completes it rather than adding
  # a second one.
  def test_a_heading_the_commands_wrote_is_completed_not_duplicated
    text = FIXTURE.sub("## QA", "### #48\n\n#### Decisions\n\n## QA")

    out = Autopilot::Log.slice_section(text, issue: 48, title: "Top-down format", pr: 71, sha: "5bc96eb", row: ROW)

    assert_equal 1, out.scan(/^### #48/).size
    assert_equal 1, section(out, "### #48").scan("#### Decisions").size
  end

  # The template's header row has no data row under it; a command that copied
  # it must not lose the line after the table.
  def test_a_header_table_without_a_data_row_is_completed_not_overwritten
    text = FIXTURE.sub("## QA", "### #48\n\n| Added | Files | Review rounds | Fixed | Dropped | Wall time | Usage |\n" \
                                "|---|---|---|---|---|---|---|\n#### Bugs found and fixed\n- a bug\n\n## QA")

    mine = section(Autopilot::Log.slice_section(text, issue: 48, title: "T", pr: 71, sha: "5bc96eb", row: ROW), "### #48")

    assert_includes mine, "#### Bugs found and fixed\n- a bug"
    assert_equal 1, mine.scan("| Added |").size
    assert_includes mine, "| 420 | 6 |"
  end

  def test_the_template_inside_the_comment_is_left_alone
    assert_includes landed, "<!-- One section per slice, in merge order:\n\n### #<issue> — <title> (PR #<n>, merged <SHA>)\n"
  end

  USAGE = [
    { "step" => "/task_plan 48", "kind" => "ok", "usd" => 1.5, "seconds" => 240 },
    { "step" => "/implement 48", "kind" => "usage_limit", "usd" => 0.0, "seconds" => 30 },
    { "step" => "/implement 48", "kind" => "error", "usd" => 3.0, "seconds" => 1800 },
    { "step" => "/implement 48", "kind" => "ok", "usd" => 4.25, "seconds" => 2100 },
    { "step" => "/pr_review 71", "kind" => "ok", "usd" => 2.0, "seconds" => 600 },
    { "step" => "/pr_comment_resolver 71", "kind" => "ok", "usd" => 1.0, "seconds" => 300 },
    { "step" => "/pr_review 71", "kind" => "ok", "usd" => 1.0, "seconds" => 400 }
  ].freeze

  def test_metrics_are_one_row_per_step_with_retries_and_pauses_counted
    text = Autopilot::Log.metrics(FIXTURE, 48, USAGE)
    rows = text.lines.grep(/^\| #48 \|/)

    assert_equal 5, rows.size, "the two review passes are two rows"
    assert_equal "| #48 | `/implement 48` | 1h 5m | $7.25 | 1 | 1 |\n", rows[1]
    assert_equal "| #48 | `/task_plan 48` | 4m 0s | $1.50 | 0 | 0 |\n", rows[0]
    assert_equal text, Autopilot::Log.metrics(text, 48, USAGE), "rerun replaces, not appends"
    assert text.index("| #47 |") < text.index("| #48 |")
  end

  def test_the_driver_s_own_waits_are_never_retries
    waits = [ { "step" => "CI wait, PR #71", "kind" => "driver", "seconds" => 2700 },
              { "step" => "CI wait, PR #71", "kind" => "driver", "seconds" => 300 } ]

    assert_equal [ { step: "CI wait, PR #71", seconds: 3000, usd: 0.0, retries: 0, pauses: 0 } ], Autopilot::Log.step_rows(waits)
  end

  def test_pauses_are_written_once
    pause = { "step" => "/implement 48", "at" => "2026-10-02T01:00:00Z", "until" => "2026-10-02T03:00:00Z" }
    text = Autopilot::Log.pauses(FIXTURE, [ pause ])

    halts = section(text, "## Halts and pauses")
    assert_includes halts, "#### PAUSE · usage limit · /implement 48\n- **At:** 2026-10-02T01:00:00Z · **Resumed:** 2026-10-02T03:00:00Z"
    assert_equal text, Autopilot::Log.pauses(text, [ pause ])
  end

  def test_read_this_first_ranks_one_way_then_costly_then_the_rest_in_log_order
    text = Autopilot::Log.read_this_first(landed)
    items = section(text, "## Read this first").lines.grep(/^- /).map(&:chomp)

    assert_equal [
      "- **one-way** · issue filed in #47 · #60 `/cart` exposes its item limit — found in the manual check",
      "- **one-way** · D48-3 · `choice` · Add a `format` column to players?",
      "- **costly** · D47-2 · `choice` · Reconnect backoff: fixed or exponential?",
      "- **dropped** · #47 · Token in the cable URL — probe: `grep -n token app/channels` shows none — `app/channels/application_cable/connection.rb:12`",
      "- **opinion** · D48-2 · `opinion` · Which format reads best on a phone?",
      "- **halt** · `comments` · a person commented on PR #67"
    ], items
    refute_includes items.join, "<claim>", "the template inside the comment is not an entry"
    refute_includes items.join, "D47-1", "cheap entries stay out"
    assert_equal text, Autopilot::Log.read_this_first(text), "regenerated, not appended"
  end

  def test_the_run_line_names_the_span_and_the_total
    text = Autopilot::Log.run_line(FIXTURE, started: "2026-10-02T01:00:00Z", finished: "2026-10-03T09:00:00Z", usd: 51.5)

    assert_includes text, "**Run:** 2026-10-02T01:00:00Z → 2026-10-03T09:00:00Z · **Usage:** $51.50 (estimate)\n"
  end
end

# The autopilot worktree gets its own databases through DB_SUFFIX. Unset, the
# names must be exactly today's, so nobody else's setup changes. A generated
# app has it; an adopted one adds it by hand (docs/sop/run-a-feature-on-autopilot.md),
# and until then these skip rather than fail.
class AutopilotDatabaseSuffixTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  DATABASE_YML = File.join(ROOT, "config/database.yml")
  ROLES = %w[primary queue cable cache].freeze

  def setup
    return if File.exist?(DATABASE_YML) && File.read(DATABASE_YML).include?("DB_SUFFIX")

    skip "config/database.yml has no DB_SUFFIX: add it by hand (docs/sop/run-a-feature-on-autopilot.md)"
  end

  def test_names_are_unchanged_without_a_suffix
    config = render(nil)

    assert_match(/_development\z/, config.dig("development", "primary", "database"))
    assert_match(/_development_queue\z/, config.dig("development", "queue", "database"))
    assert_match(/_test\z/, config.dig("test", "primary", "database"))
    assert_match(/_test_cache\z/, config.dig("test", "cache", "database"))
  end

  def test_every_development_and_test_database_carries_the_suffix
    config = render("_autopilot")

    %w[development test].each do |env|
      ROLES.each do |role|
        name = config.dig(env, role, "database")
        assert name.end_with?("_autopilot"), "#{env}.#{role} is #{name.inspect}"
      end
    end
  end

  def test_production_ignores_the_suffix
    config = render("_autopilot")

    ROLES.each do |role|
      refute_match(/_autopilot\z/, config.dig("production", role, "database").to_s, "production.#{role}")
    end
  end

  private

  def render(suffix)
    previous = ENV.fetch("DB_SUFFIX", nil)
    suffix ? ENV["DB_SUFFIX"] = suffix : ENV.delete("DB_SUFFIX")
    YAML.safe_load(ERB.new(File.read(DATABASE_YML)).result, aliases: true)
  ensure
    previous ? ENV["DB_SUFFIX"] = previous : ENV.delete("DB_SUFFIX")
  end
end
