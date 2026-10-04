# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"
require "fileutils"

# The Claude Code settings adopted from the template, and the hooks they wire.
# Plain Minitest, like test/bin/autopilot_test.rb: no Rails, no database.

ROOT = File.expand_path("../..", __dir__)

class ClaudeSettingsTest < Minitest::Test
  SETTINGS = JSON.parse(File.read(File.join(ROOT, ".claude/settings.json")))

  def hook_commands(event) = SETTINGS.dig("hooks", event).to_a.flat_map { |entry| entry["hooks"].map { |hook| hook["command"] } }

  def test_every_wired_hook_exists_and_is_executable
    commands = SETTINGS.fetch("hooks").keys.flat_map { |event| hook_commands(event) }

    refute_empty commands
    commands.each do |command|
      path = File.join(ROOT, command)
      assert File.executable?(path), "#{command} is wired but not an executable file"
    end
  end

  def test_the_template_hooks_and_deny_list_are_in_place
    assert_includes hook_commands("PostToolUse"), "bin/hooks/post_edit"
    assert_includes hook_commands("Stop"), "bin/hooks/session_end"
    assert_includes hook_commands("PreToolUse"), "bin/hooks/autopilot_guard"
    deny = SETTINGS.dig("permissions", "deny")
    [ "Read(./config/master.key)", "Bash(git push --force:*)", "Bash(git reset --hard:*)", "Bash(git clean -fd:*)" ].each do |rule|
      assert_includes deny, rule
    end
  end
end

# bin/hooks/session_end, run for real in a scratch repo.
class SessionEndHookTest < Minitest::Test
  HOOK = File.join(ROOT, "bin/hooks/session_end")

  def setup
    @global = ENV.fetch("GIT_CONFIG_GLOBAL", nil)
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    @dir = Dir.mktmpdir
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t")
    git("config", "user.name", "t")
    FileUtils.mkdir_p(File.join(@dir, "docs/system"))
    File.write(File.join(@dir, "docs/system/thing.md"), "# Thing\n\n**Status:** Draft — created for #5.\n")
    git("add", "-A")
    git("commit", "-qm", "base")
  end

  def teardown
    FileUtils.remove_entry(@dir)
    @global ? ENV["GIT_CONFIG_GLOBAL"] = @global : ENV.delete("GIT_CONFIG_GLOBAL")
  end

  def git(*args) = system("git", *args, chdir: @dir, out: File::NULL, err: File::NULL) || raise("git #{args.join(' ')}")

  def hook_status(env = { "AUTOPILOT" => nil, "SKIP_DRAFT_CHECK" => nil })
    _out, status = Open3.capture2e(env, HOOK, chdir: @dir, stdin_data: "{}")
    status.exitstatus
  end

  def test_a_slice_branch_with_its_own_draft_still_blocks
    git("checkout", "-qb", "feat/5/thing")

    assert_equal 2, hook_status
  end

  # In a `claude -p` step a Stop hook that exits 2 keeps the agent going: a
  # probe on this slice's branch looped 36 times on its own Draft.
  def test_an_autopilot_step_is_never_held_by_its_own_draft
    git("checkout", "-qb", "feat/5/thing")

    assert_equal 0, hook_status("AUTOPILOT" => "1")
  end

  # The driver's detached steps would otherwise loop on every draft in docs/.
  def test_a_detached_head_says_nothing
    git("checkout", "-q", "--detach")

    assert_equal 0, hook_status
  end

  # A feature's drafts are completed at the feature PR, not in any session on
  # its branch; blocking here looped a merge session on every turn.
  def test_a_feature_branch_says_nothing
    git("checkout", "-qb", "feature/thing")

    assert_equal 0, hook_status
  end

  # A developer's local opt-out (settings.local.json `env`), for drafts that
  # are legitimately open where they work, such as main during a feature.
  def test_skip_draft_check_says_nothing
    assert_equal 0, hook_status("SKIP_DRAFT_CHECK" => "1")
  end

  def test_main_still_blocks_on_any_draft
    assert_equal 2, hook_status
  end
end

# bin/hooks/autopilot_guard, run as Claude Code runs it: the tool call as JSON
# on stdin, exit 2 to deny.
class AutopilotGuardTest < Minitest::Test
  HOOK = File.join(ROOT, "bin/hooks/autopilot_guard")

  def guard(payload, autopilot: true)
    env = { "AUTOPILOT" => autopilot ? "1" : nil }
    stdin = payload.is_a?(String) ? payload : JSON.generate(payload)
    out, status = Open3.capture2e(env, HOOK, stdin_data: stdin)
    [ status.exitstatus, out ]
  end

  def bash(command) = { "tool_name" => "Bash", "tool_input" => { "command" => command } }
  def edit(path, text = "x") = { "tool_name" => "Edit", "tool_input" => { "file_path" => "/w/#{path}", "old_string" => "a", "new_string" => text } }
  def write(path, text) = { "tool_name" => "Write", "tool_input" => { "file_path" => "/w/#{path}", "content" => text } }

  DENIED = {
    "in-step merge" => [ "gh pr merge 70 --squash" ],
    "merge hidden in ruby" => [ %q(ruby -e 'system("gh pr merge 70")') ],
    "merge endpoint" => [ "gh api -X PUT repos/acme/shop/pulls/70/merge" ],
    "graphql merge" => [ %q(gh api graphql -f query='mutation { mergePullRequest(input: {pullRequestId: "x"}) { clientMutationId } }') ],
    "push to main" => [ "git push origin main", "git push origin HEAD:main", "git push origin HEAD:refs/heads/main" ],
    "force push" => [ "git push --force", "git push -f origin HEAD", "git push --force-with-lease", "git push origin +HEAD:feat/1/x",
                      "git -C /w push -uf origin HEAD", "git --no-pager push -f origin HEAD", %q(bundle exec ruby -e '`git push --force`') ],
    "forced ref moves" => [ "gh api -X PATCH repos/o/r/git/refs/heads/feature/x -f sha=abc -F force=true" ],
    "git aliases" => [ %q(ruby -e 'system("git config alias.p \"push --force\"")'), %q(git -c alias.p='push --force' p),
                       "git config remote.origin.push +HEAD:refs/heads/x", "git config push.default current" ],
    "ready" => [ "gh pr ready 66" ],
    "bead closes" => [ "bd close bd-a3f2", "bd delete acme-a3f2", "bd update a3f2 --status closed", "bd update a3f2 --status=closed",
                       %q(ruby -e 'system("bd close a3f2")') ],
    "board deletes" => [ "gh project item-delete 1 --owner o --id PVTI_1", "gh project delete 1 --owner o",
                         "gh project close 1 --owner o", "gh project item-archive 1 --owner o --id PVTI_1" ],
    "close" => [ "gh issue close 61", "gh api -X PATCH repos/o/r/issues/61 -f state=closed",
                 %q(gh api -X PATCH repos/o/r/issues/61 -f "state=closed"), %q(gh api -X PATCH repos/o/r/issues/61 -f 'state=closed') ],
    "branch deletes" => [ "git push origin --delete feature/autopilot", "git push origin :feature/autopilot", "git push -d origin feat/1/x",
                          "gh api -X DELETE repos/o/r/git/refs/heads/feature/autopilot",
                          "gh api --method=DELETE repos/o/r/git/refs/heads/feature/x" ],
    "rebase a PR" => [ "gh pr edit 70 --base main", "gh pr edit 70 -B main", "gh api -X PATCH repos/o/r/pulls/70 -f base=main" ],
    "main ref" => [ "gh api -X PATCH repos/o/r/git/refs/heads/main -f sha=abc", "git update-ref refs/heads/main abc" ],
    "checking out main" => [ "git checkout main && git push origin HEAD", "git switch main", "git checkout -B main origin/feature/x",
                               "git worktree add ../x main" ],
    "api writes to main" => [ "gh api -X POST repos/o/r/merges -f base=main -f head=feature/x",
                                "gh api -X PUT repos/o/r/contents/a.md -f branch=main -f message=x -f content=eA==",
                                "gh api -X POST repos/o/r/merges -f base=feature/x -f head=feat/1/y",
                                "gh api -X POST repos/o/r/branches/main/rename -f new_name=x",
                                %q(gh api -X PUT repos/o/r/contents/a.md -f "branch=main" -f message=x),
                                %q(gh api -X POST repos/o/r/git/tags --input - <<< '{"ref": "main"}') ],
    "graphql branch moves" => [ %q(gh api graphql -f query='mutation { mergeBranch(input: {}) { clientMutationId } }'),
                                %q(gh api graphql -f query='mutation { createCommitOnBranch(input: {}) { clientMutationId } }'),
                                %q(gh api graphql -f query='mutation { updateRef(input: {refId: "x", oid: "y", force: true}) { clientMutationId } }') ],
    "credentials" => [ "cat config/credentials/production.key", "rm -rf .github/workflows/ci.yml" ],
    "wiring" => [ "sed -i '' 's/x/y/' .claude/settings.json", "rm bin/hooks/autopilot_guard", "echo Bash >> .claude/autopilot-allowed-tools.txt" ],
    "destructive migration" => [ "bin/rails g migration RemoveEmailFromPlayers email:string", "bin/rails generate migration drop_old_table",
                                 %q(ruby -e 'File.write("db/migrate/1_x.rb", "drop_table :x")') ]
  }.freeze

  DENIED.each do |rule, commands|
    define_method("test_denies_#{rule.tr(' -', '__')}") do
      commands.each do |command|
        status, out = guard(bash(command))
        assert_equal 2, status, "not denied: #{command}"
        assert_match(/Denied by the autopilot guard: .*\n.*halt/m, out)
      end
    end

    define_method("test_lets_#{rule.tr(' -', '__')}_through_without_autopilot") do
      commands.each { |command| assert_equal 0, guard(bash(command), autopilot: false).first, command }
    end
  end

  def test_everyday_commands_pass
    [
      "git push -u origin HEAD", "git push origin HEAD", "git push", "git push --follow-tags",
      "gh pr view 70", "gh pr create --base feature/autopilot --title x --body y", "gh pr edit 66 --body-file tmp/b.md",
      "gh api --paginate repos/o/r/pulls/70/reviews", "git commit -m 'Let the driver push to main later'",
      "bin/rails g migration AddEmailToPlayers email:string", "git log --oneline -- db/migrate", "bin/test",
      "git fetch origin main", "git merge-base --is-ancestor origin/main HEAD", "git checkout -b feat/1/x origin/feature/x",
      "gh api repos/o/r/branches/main", "git log origin/main..HEAD",
      "gh issue list --state=closed", "gh api 'repos/o/r/issues?state=closed'",
      "bd update a3f2 --status in_progress", "bd set-state a3f2 lifecycle=up_for_review", "bd show a3f2 --json",
      "bd list --status closed", "gh project item-edit --project-id P --id I --field-id F --single-select-option-id O",
      # Main named in a reply's text, not as its target.
      %q(gh api -X POST repos/o/r/pulls/117/comments/4172007325/replies -f body="Addressed: the bug is already on main; filed #118"),
      %q(gh pr comment 117 --body "Fixed on main already")
    ].each { |command| assert_equal 0, guard(bash(command)).first, command }
  end

  def test_edits_to_guarded_paths_are_denied_and_others_pass
    assert_equal 2, guard(edit("config/credentials/production.yml.enc")).first
    assert_equal 2, guard(write(".github/workflows/ci.yml", "on: push")).first
    assert_equal 2, guard(edit(".claude/settings.json")).first
    assert_equal 2, guard(edit("bin/hooks/session_end")).first
    assert_equal 2, guard(edit("bin/autopilot")).first
    assert_equal 2, guard({ "tool_name" => "NotebookEdit", "tool_input" => { "notebook_path" => "/w/.github/workflows/x.ipynb" } }).first
    assert_equal 0, guard(edit("app/models/player.rb")).first
    assert_equal 0, guard(edit("config/credentials/production.yml.enc"), autopilot: false).first
  end

  def test_a_migration_edit_is_denied_only_when_it_destroys
    assert_equal 2, guard(write("db/migrate/20261002_drop.rb", "def change\n  drop_table :old\nend\n")).first
    assert_equal 2, guard(edit("db/migrate/20261002_x.rb", "remove_column :players, :email")).first
    multi = { "tool_name" => "MultiEdit", "tool_input" => { "file_path" => "/w/db/migrate/1_x.rb",
                                                            "edits" => [ { "old_string" => "a", "new_string" => "rename_column :a, :b, :c" } ] } }
    assert_equal 2, guard(multi).first
    assert_equal 0, guard(write("db/migrate/20261002_add.rb", "add_column :players, :email, :string")).first
    assert_equal 0, guard(edit("app/models/x.rb", "drop_table is a word in a comment")).first
  end

  # A guard that crashes open is no guard; without autopilot it is never in the way.
  def test_an_unreadable_call_is_denied_under_autopilot_only
    assert_equal 2, guard("not json").first
    assert_equal 2, guard({ "tool_name" => "Bash" }).first
    assert_equal 0, guard("not json", autopilot: false).first
  end

  # `git push` names no branch; from a checked-out main it pushes main.
  def test_a_plain_push_from_a_checked_out_main_is_denied
    Dir.mktmpdir do |dir|
      system("git", "init", "-q", "-b", "main", dir, exception: true)
      payload = bash("git push").merge("cwd" => dir)
      assert_equal 2, guard(payload).first
      system("git", "-C", dir, "checkout", "-q", "-b", "feat/1/x", exception: true)
      assert_equal 0, guard(payload).first
    end
  end

  # The developer's own checkout sits beside the worktree; a step must not
  # push from it, however it gets there.
  def test_a_push_from_another_checkout_is_denied
    Dir.mktmpdir do |dir|
      mine = File.join(dir, "worktree")
      theirs = File.join(dir, "shop")
      [ mine, theirs ].each { |repo| system("git", "init", "-q", "-b", "feat/1/x", repo, exception: true) }
      [ "git -C ../shop push", "cd ../shop && git push", "cd #{theirs}; git push origin HEAD", "git -C ../missing push" ].each do |command|
        assert_equal 2, guard(bash(command).merge("cwd" => mine)).first, command
      end
      FileUtils.mkdir_p(File.join(mine, "tmp"))
      [ "git push -u origin HEAD", "git -C . push", "cd tmp && git push" ].each do |command|
        assert_equal 0, guard(bash(command).merge("cwd" => mine)).first, command
      end
    end
  end

  def test_tools_it_does_not_guard_pass
    assert_equal 0, guard({ "tool_name" => "Read", "tool_input" => { "file_path" => "/w/config/credentials.yml.enc" } }).first
  end
end
