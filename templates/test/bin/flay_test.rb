# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "open3"

# bin/flay is a git-aware wrapper, so drive it against a throwaway repo rather
# than mocking flay: base commit with one method, then a working tree that
# either copies it verbatim, copies it with a changed literal, or leaves it.
class FlayGateTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  # Mass 29 — flay ignores nodes under 16, so the fixture has to be real-sized.
  METHOD = <<~RUBY
    def total(items)
      return 0 if items.empty?

      subtotal = items.sum { |item| item.price * item.quantity }
      tax = (subtotal * TAX_RATE).round(2)
      subtotal + tax + shipping_for(items)
    end
  RUBY

  # Two methods that share only a guard clause: the :defn nodes differ, the :if
  # nodes are Similar (one literal apart) and above the mass threshold.
  GUARDED = <<~RUBY
    def one(items)
      if items.empty?
        Rails.logger.warn("missing items for \#{name} in \#{self.class}")
        return failure("missing", code: 1, retry: false)
      end

      items.map { |item| [item.id, item.price] }
    end
  RUBY

  def setup
    @repo = Dir.mktmpdir
    Dir.chdir(@repo) do
      `git init -q && git config user.email t@t && git config user.name t`
      Dir.mkdir("app")
      write("app/a.rb", "class A\n#{METHOD}end\n")
      `git add -A && git commit -qm base`
    end
  end

  def teardown
    FileUtils.remove_entry(@repo)
  end

  def test_passes_when_nothing_is_duplicated
    write("app/b.rb", "class B\n  def other = 1\nend\n")

    out, status = run_gate

    assert status.success?, out
    assert_includes out, "no copied code"
  end

  def test_fails_on_verbatim_copy
    write("app/b.rb", "class B\n#{METHOD}end\n")

    out, status = run_gate

    refute status.success?, out
    assert_includes out, "1 copied block(s) added"
    assert_includes out, "+ app/b.rb:2"
    assert_includes out, "+ app/a.rb:2"
  end

  def test_fails_on_renamed_copy_with_a_literal_changed
    write("app/b.rb", "class B\n#{METHOD.sub('total', 'grand_total').sub('quantity', 'count')}end\n")

    out, status = run_gate

    refute status.success?, out
    assert_includes out, "1 copied block(s) added"
    assert_includes out, "Similar code in :defn"
  end

  # flay hashes sub-nodes only, so a namespaced class is a node and subsumes its
  # methods; the copied file then surfaces as one Similar :class, not N defns.
  def test_fails_on_whole_file_copied_under_a_new_class_name
    write("app/a.rb", "module Billing\n  class A\n#{METHOD.gsub(/^/, '  ')}  end\nend\n")
    Dir.chdir(@repo) { `git add -A && git commit -qm namespaced` }
    write("app/b.rb", File.read(File.join(@repo, "app/a.rb")).sub("class A", "class B"))

    out, status = run_gate

    refute status.success?, out
    assert_includes out, "Similar code in :class"
  end

  def test_warns_only_on_a_similar_shape_inside_different_methods
    write("app/b.rb", "class B\n#{GUARDED.sub('one', 'two').sub('missing', 'absent').sub(/items\.map.*/, 'items.pluck(:id, :price).to_h')}end\n")
    Dir.chdir(@repo) { `git add -A && git commit -qm guarded` }
    write("app/c.rb", "class C\n#{GUARDED}end\n")

    out, status = run_gate

    assert status.success?, out
    assert_includes out, "1 similar block(s) added"
    assert_includes out, "Similar code in :if"
  end

  def test_passes_when_existing_duplication_is_unchanged
    Dir.chdir(@repo) do
      write("app/b.rb", "class B\n#{METHOD}end\n")
      `git add -A && git commit -qm dup`
    end
    write("app/c.rb", "class C\n  def other = 1\nend\n")

    out, status = run_gate

    assert status.success?, out
  end

  def test_aborts_when_base_does_not_resolve
    out, status = run_gate("BASE" => "no-such-ref")

    refute status.success?, out
    assert_includes out, "BASE no-such-ref is not a commit here"
  end

  private

  def write(path, body)
    File.write(File.join(@repo, path), body)
  end

  def run_gate(overrides = {})
    env = { "BASE" => "HEAD", "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile") }.merge(overrides)
    out, err, status = Open3.capture3(env, File.join(ROOT, "bin/flay"), chdir: @repo)
    [ out + err, status ]
  end
end
