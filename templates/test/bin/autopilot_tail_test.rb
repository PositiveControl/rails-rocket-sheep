# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "stringio"
require "tmpdir"
require "fileutils"

load File.expand_path("../../bin/autopilot-tail", __dir__)

# bin/autopilot-tail. Plain Minitest, like test/bin/autopilot_test.rb.
class AutopilotTailTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @out = StringIO.new
  end

  def teardown = FileUtils.remove_entry(@dir)

  def event(type, content) = { "type" => type, "timestamp" => "2026-10-06T18:00:00Z", "message" => { "content" => content } }

  def step_prompt(name, args) = event("user", "<command-message>x</command-message>\n<command-name>/#{name}</command-name>\n<command-args>#{args}</command-args>")

  def append(path, *events)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, "a") { |io| events.each { |e| io.puts(e.to_json) } }
  end

  def test_render_shows_tool_calls_text_and_errors_and_hides_thinking
    calls = AutopilotTail.render(event("assistant", [ { "type" => "thinking", "thinking" => "hmm" },
                                                      { "type" => "text", "text" => "Running the tests." },
                                                      { "type" => "tool_use", "name" => "Bash", "input" => { "command" => "bin/test x" } } ]))
    results = AutopilotTail.render(event("user", [ { "type" => "tool_result", "is_error" => true, "content" => "boom\nmore" } ]))

    assert_equal [ [ :text, "Running the tests." ], [ :tool, "→ Bash: bin/test x" ] ], calls
    assert_equal [ [ :error, "✗ boom" ] ], results
    assert_equal "/pr_submit 48", AutopilotTail.command(step_prompt("pr_submit", "48").dig("message", "content"))
  end

  # The point of the script: a step that starts after it, and that step's
  # subagent, are followed without restarting it.
  def test_a_new_step_session_and_its_subagent_are_followed_as_they_appear
    append("#{@dir}/old.jsonl", step_prompt("task_plan", "48"))
    follower = AutopilotTail::Follower.new(@dir, replay_all: false, out: @out)

    append("#{@dir}/new.jsonl", step_prompt("implement", "48"))
    follower.poll
    append("#{@dir}/new.jsonl", event("assistant", [ { "type" => "tool_use", "name" => "Edit", "input" => { "file_path" => "app/x.rb" } } ]))
    append("#{@dir}/new/subagents/agent-1.jsonl", event("assistant", [ { "type" => "text", "text" => "Reviewing." } ]))
    follower.poll

    assert_match(/step \/implement 48/, @out.string)
    assert_match(/\/implement 48 → Edit: app\/x.rb/, @out.string)
    assert_match(/\/implement 48 ›agent Reviewing\./, @out.string)
  end

  # A line still being written is held until its newline arrives.
  def test_a_half_written_line_waits_for_the_rest
    append("#{@dir}/s.jsonl", step_prompt("implement", "1"))
    follower = AutopilotTail::Follower.new(@dir, replay_all: false, out: @out)
    line = event("assistant", [ { "type" => "text", "text" => "Done." } ]).to_json

    File.write("#{@dir}/s.jsonl", line[0, 20], mode: "a")
    follower.poll
    refute_match(/Done\./, @out.string)

    File.write("#{@dir}/s.jsonl", "#{line[20..]}\n", mode: "a")
    follower.poll
    assert_match(/Done\./, @out.string)
  end
end
