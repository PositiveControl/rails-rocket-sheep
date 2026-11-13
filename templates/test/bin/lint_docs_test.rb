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
    @root = Dir.mktmpdir
    @env = %w[GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM XDG_CONFIG_HOME].to_h { |key| [ key, ENV.fetch(key, nil) ] }
    ENV["GIT_CONFIG_GLOBAL"] = File::NULL
    ENV["GIT_CONFIG_NOSYSTEM"] = "1"
    ENV["XDG_CONFIG_HOME"] = @root # no personal ~/.config/git/ignore either
    @dir = File.join(@root, "app")
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
    FileUtils.remove_entry(@root)
    @env.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  def git(*args, chdir: @dir) = system("git", *args, chdir:, out: File::NULL, err: File::NULL) || raise("git #{args.join(' ')}")

  def write(path, body)
    FileUtils.mkdir_p(File.dirname(File.join(@dir, path)))
    File.write(File.join(@dir, path), body)
  end

  def lint(env = {})
    out, status = Open3.capture2e(env, RbConfig.ruby, "templates/bin/lint-docs", chdir: @dir)
    [ out, status.exitstatus ]
  end

  def test_the_copy_is_clean_to_begin_with
    out, code = lint

    assert_equal 0, code, out
  end

  # An autopilot step's PR body and task file are scratch, and say what they like.
  RISK = "# Cart total drifts\n\n**Status:** open\n**Area:** `app/models/cart.rb`\n"

  def list_risks(*lines)
    index = File.read(File.join(@dir, "templates/docs/risks/INDEX.md"))
    write("templates/docs/risks/INDEX.md", index.sub("<!-- risks:end -->", "#{lines.map { |line| "#{line}\n" }.join}<!-- risks:end -->"))
  end

  def test_a_listed_risk_with_its_status_is_clean
    write("templates/docs/risks/2026-10-02-cart-total.md", RISK)
    list_risks("- [Cart total drifts](2026-10-02-cart-total.md) — open")
    out, = lint

    # The ship check still names the file (risks are an app's own, never the
    # template's); nothing about the index does.
    refute_match(%r{docs/risks/INDEX\.md:}, out)
  end

  # A risk nobody lists is one nobody reads; a union merge can leave a
  # duplicate, or a stale line beside a status change.
  def test_the_risk_index_must_list_every_risk_once_with_its_status
    write("templates/docs/risks/2026-10-02-cart-total.md", RISK)
    write("templates/docs/risks/2026-10-03-unlisted.md", RISK)
    list_risks("- [Cart total drifts](2026-10-02-cart-total.md) — open",
               "- [Cart total drifts](2026-10-02-cart-total.md) — retired",
               "- [Gone](2026-10-04-gone.md) — open")
    out, code = lint

    assert_equal 1, code
    assert_includes out, "lists 2026-10-02-cart-total.md 2 times"
    assert_includes out, "lists 2026-10-02-cart-total.md as retired, the file says open"
    assert_includes out, "does not list 2026-10-03-unlisted.md"
    assert_includes out, "lists 2026-10-04-gone.md, which does not exist"
  end

  def test_gitignored_scratch_is_not_scanned
    write("tmp/pr-body-1.md", WRONG_COUNT + REAL_HOST)

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

  # No git on PATH at all, not just no repository.
  def test_without_a_git_binary_it_falls_back_to_the_whole_tree
    FileUtils.rm_rf(File.join(@dir, ".git"))
    write("tmp/pr-body-1.md", WRONG_COUNT)

    out, code = lint("PATH" => File.join(@root, "empty-bin"))

    assert_equal 1, code, out
    assert_includes out, "tmp/pr-body-1.md:1: claims 10 commands" # lint-docs:ignore
  end

  # Unpacked inside another repo that ignores it: git answers, with nothing.
  def test_a_checkout_an_outer_repo_ignores_falls_back_to_the_whole_tree
    FileUtils.rm_rf(File.join(@dir, ".git"))
    git("init", "-q", chdir: @root)
    File.write(File.join(@root, ".gitignore"), "app/\n")
    write("docs/untracked.md", WRONG_COUNT)

    out, code = lint

    assert_equal 1, code, out
    assert_includes out, "docs/untracked.md:1: claims 10 commands" # lint-docs:ignore
  end
end
