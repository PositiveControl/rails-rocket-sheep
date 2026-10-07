# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"

# bin/dogfood-sync, run for real against a committed copy of this repo. The
# sync is this repo's tooling and ships nowhere, so its test lives at the root,
# not under templates/test/.

REPO = File.expand_path("../..", __dir__)

class DogfoodSyncTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    @env = %w[GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM XDG_CONFIG_HOME AUTOPILOT].to_h { |key| [ key, ENV.fetch(key, nil) ] }
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    ENV["GIT_CONFIG_NOSYSTEM"] = "1"
    ENV["XDG_CONFIG_HOME"] = @root
    ENV.delete("AUTOPILOT")
    @dir = File.join(@root, "repo")
    files, status = Open3.capture2("git", "-C", REPO, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    raise "git ls-files failed" unless status.success?

    files.split("\0").each do |file|
      source = File.join(REPO, file)
      next unless File.file?(source)

      FileUtils.mkdir_p(File.dirname(File.join(@dir, file)))
      FileUtils.cp(source, File.join(@dir, file), preserve: true)
    end
    git("init", "-q")
    git("add", "-A")
    git("-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-qm", "copy")
  end

  def teardown
    FileUtils.remove_entry(@root)
    @env.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  def git(*args) = system("git", *args, chdir: @dir, out: File::NULL, err: File::NULL) || raise("git #{args.join(' ')}")

  def path(rel) = File.join(@dir, rel)

  def sync
    out, status = Open3.capture2e(RbConfig.ruby, "bin/dogfood-sync", chdir: @dir)
    [ out, status.exitstatus ]
  end

  def dirty
    Open3.capture2("git", "status", "--porcelain", "--untracked-files=all", chdir: @dir).first
  end

  def test_the_committed_root_is_in_step
    out, code = sync

    assert_equal 0, code, out
    assert_match "in step with templates/", out
    assert_equal "", dirty
  end

  def test_a_umask_difference_is_not_a_change
    File.chmod(0o664, path("WORKFLOW.md"))

    out, code = sync

    assert_equal 0, code, out
    assert_match "in step with templates/", out
  end

  def test_an_edited_template_command_rewrites_both_copies
    File.write(path("templates/.claude/commands/pick.md"), "\nstale\n", mode: "a")

    out, code = sync

    assert_equal 0, code, out
    assert_equal " M .claude/commands/pick.md\n M .cursor/commands/pick.md\n", dirty.sub(" M templates/.claude/commands/pick.md\n", "")
  end

  def test_a_hook_the_template_adds_reaches_the_root
    File.write(path("templates/bin/hooks/new_hook"), "#!/bin/sh\n")
    File.chmod(0o755, path("templates/bin/hooks/new_hook"))

    out, code = sync

    assert_equal 0, code, out
    assert File.executable?(path("bin/hooks/new_hook")), out
  end

  def test_a_hook_or_command_the_template_drops_is_removed
    File.delete(path("templates/bin/hooks/post_edit"))
    File.delete(path("templates/.claude/commands/grill.md"))

    out, code = sync

    assert_equal 0, code, out
    assert_match "bin/hooks/post_edit (removed)", out
    %w[bin/hooks/post_edit .claude/commands/grill.md .cursor/commands/grill.md].each do |rel|
      refute File.exist?(path(rel)), rel
    end
  end

  def test_a_tracked_file_nobody_owns_fails_naming_it
    File.write(path("bin/stray"), "x\n")
    git("add", "bin/stray")

    out, code = sync

    assert_equal 1, code, out
    assert_match "neither synced nor in HAND_KEPT", out
    assert_match "  bin/stray", out
  end

  def test_refuses_inside_an_autopilot_step
    out, status = Open3.capture2e({ "AUTOPILOT" => "1" }, RbConfig.ruby, "bin/dogfood-sync", chdir: @dir)

    assert_equal 1, status.exitstatus, out
    assert_equal "", dirty
  end
end
