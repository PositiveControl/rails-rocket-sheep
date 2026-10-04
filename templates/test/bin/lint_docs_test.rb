# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"

# templates/bin/lint-docs in the template repo, run for real against a copy of
# it. This repo's own test, not an app's: nothing copies it, because an app never
# runs the template-repo branch it covers.

REPO = File.expand_path("../../..", __dir__)

class LintDocsRepoScanTest < Minitest::Test
  WRONG_COUNT = "The 10 commands live here.\n" # lint-docs:ignore
  REAL_HOST = "ssh deploy@db.acme-prod.com, or 8.8.8.8\n" # lint-docs:ignore

  def setup
    @global = ENV.fetch("GIT_CONFIG_GLOBAL", nil)
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    @dir = Dir.mktmpdir
    files, status = Open3.capture2("git", "-C", REPO, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    raise "git ls-files failed" unless status.success?

    files.split("\0").each do |file|
      source = File.join(REPO, file)
      next unless File.file?(source)

      FileUtils.mkdir_p(File.dirname(File.join(@dir, file)))
      FileUtils.cp(source, File.join(@dir, file), preserve: true)
    end
    git("init", "-q")
  end

  def teardown
    FileUtils.remove_entry(@dir)
    @global ? ENV["GIT_CONFIG_GLOBAL"] = @global : ENV.delete("GIT_CONFIG_GLOBAL")
  end

  def git(*args) = system("git", *args, chdir: @dir, out: File::NULL, err: File::NULL) || raise("git #{args.join(' ')}")

  def write(path, body)
    FileUtils.mkdir_p(File.dirname(File.join(@dir, path)))
    File.write(File.join(@dir, path), body)
  end

  def lint
    out, status = Open3.capture2e("ruby", "templates/bin/lint-docs", chdir: @dir)
    [ out, status.exitstatus ]
  end

  def test_the_copy_is_clean_to_begin_with
    out, code = lint

    assert_equal 0, code, out
  end

  # An autopilot step's PR body and task file are scratch, and say what they like.
  def test_gitignored_scratch_is_not_scanned
    write("tmp/pr-body-1.md", WRONG_COUNT + REAL_HOST)
    write(".llm/tasks/1_thing.md", WRONG_COUNT + REAL_HOST)

    out, code = lint

    assert_equal 0, code, out
  end

  # Untracked but not ignored is a doc about to be committed.
  def test_an_untracked_unignored_doc_is_still_counted
    write("docs/untracked.md", WRONG_COUNT)

    out, code = lint

    assert_equal 1, code
    assert_includes out, "docs/untracked.md:1: claims 10 commands" # lint-docs:ignore
  end

  def test_an_untracked_unignored_doc_is_still_checked_for_hosts
    write("docs/untracked.md", REAL_HOST)

    out, code = lint

    assert_equal 1, code
    assert_includes out, "docs/untracked.md:1: ssh/scp target deploy@db.acme-prod.com" # lint-docs:ignore
    assert_includes out, "docs/untracked.md:1: names the routable address 8.8.8.8" # lint-docs:ignore
  end

  # A template downloaded without .git still gets the whole tree checked.
  def test_without_git_it_falls_back_to_the_whole_tree
    FileUtils.rm_rf(File.join(@dir, ".git"))
    write("tmp/pr-body-1.md", WRONG_COUNT)

    out, code = lint

    assert_equal 1, code
    assert_includes out, "tmp/pr-body-1.md:1: claims 10 commands" # lint-docs:ignore
  end
end
