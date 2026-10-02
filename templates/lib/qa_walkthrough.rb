# frozen_string_literal: true

require "capybara"
require "capybara/dsl"
require "selenium-webdriver"
require "io/console"

# A guided UI walkthrough for a reviewer. The script changes data, drives a real
# browser to the page, and spotlights what changed — one step at a time, with a
# caption on screen. In the terminal, Enter advances and Esc quits.
#
# Run with `bin/qa-walkthrough <name>` against your own `bin/dev` server. The
# script runs inside `rails runner`, so data setup is ordinary Ruby: the app's
# models and services. The browser is only for showing. It is a demonstration,
# not a test — no assertions; the system tests own pass/fail.
#
# Two primitives make a step:
#   step "caption" do ... end     announce, run, caption on screen, pause
#   spotlight css | text: "..."   outline the element and scroll to it
# plus `sign_in(user, password:)` through Devise's form.
#
# Rules a script follows (also in .claude/commands/qa_walkthrough.md):
#   - build data with services and models, never by clicking; click only when
#     the click is the change being shown
#   - spotlight by text, not by utility classes — text survives a restyle
#   - no literal for anything a constant owns; read the constant
#   - say in the header comment what is not walked, and why
#   - the development database keeps every run's records, so anything unique
#     (an email, a slug) is found-or-created, and the script is run twice
#     before it is committed
#
# Modes (environment):
#   QA_AUTO=1         no pauses; a screenshot per step in tmp/qa_walkthrough/<name>/
#   QA_HEADLESS=1     headless Chrome — with QA_AUTO, an unattended run an agent
#                     can use to check its own script and hand over the screenshots
#   QA_HOST=url       server to drive (default http://localhost:3000)
#   QA_AUTO_DELAY=s   seconds between steps under QA_AUTO (default 0.5)
#
# A step that raises is reported and skipped, not fatal: a reviewer loses one
# screen rather than the walkthrough.
class QaWalkthrough
  include Capybara::DSL
  include Rails.application.routes.url_helpers

  # Esc (or end of input) at a pause. Not a failure, so `step` lets it through.
  Quit = Class.new(StandardError)

  def self.run(name, &block)
    new(name).run(&block)
  end

  def initialize(name)
    @name = name
    @step = 0
    @failures = []
    Capybara.run_server = false
    Capybara.app_host = ENV.fetch("QA_HOST", "http://localhost:3000")
    Capybara.default_max_wait_time = 5
    Capybara.default_driver = ENV["QA_HEADLESS"].present? ? :selenium_chrome_headless : :selenium_chrome
  end

  def run(&block)
    # The script builds records through the current models, so a database behind
    # on migrations fails on the first create with a bare NoMethodError. Say why.
    ActiveRecord::Migration.check_all_pending!
    say "== #{@name} =="
    say auto? ? "Driving #{Capybara.app_host}; screenshots in #{shot_dir}" : "Driving #{Capybara.app_host}. Enter advances, Esc quits."
    instance_exec(&block)
    say @failures.empty? ? "\nDone: #{@step} steps." : "\nDone: #{@step} steps, failed: #{@failures.join(", ")}"
    pause("Enter to close the browser.") unless auto?
  rescue Quit
    say "\nStopped at step #{@step}."
  rescue ActiveRecord::PendingMigrationError
    say "Your development database is behind on migrations. Run bin/rails db:migrate, then try again."
  ensure
    Capybara.reset_sessions!
  end

  def step(caption)
    @step += 1
    @note = nil
    say "\n[#{@step}] #{caption}"
    yield
    caption_on_screen([ "#{@step}. #{caption}", @note ].compact.join("\n"))
    screenshot if auto?
    pause
  rescue Quit
    raise
  rescue StandardError => e
    @failures << @step
    say "    ✗ #{e.class}: #{e.message.lines.first&.strip}"
    screenshot if auto?
  end

  # Outline an element and scroll it into view. `target` is a CSS selector or a
  # Capybara node; `text:` spotlights the parent of the first element whose own
  # text contains (or, with `exact: true`, equals) the string. `note` is the
  # second line of the on-screen caption — say where the number comes from.
  def spotlight(target = nil, text: nil, exact: false, note: nil)
    node =
      if text
        predicate = exact ? "normalize-space(text())=#{text.inspect}" : "contains(text(), #{text.inspect})"
        find(:xpath, "//*[#{predicate}]", match: :first).find(:xpath, "..")
      else
        target.is_a?(String) ? find(:css, target, match: :first) : target
      end
    execute_script(<<~JS, node)
      arguments[0].scrollIntoView({ block: "center" });
      arguments[0].style.outline = "4px solid #f59e0b";
      arguments[0].style.outlineOffset = "4px";
    JS
    say "    → #{note}" if note
    @note = note
  end

  # Devise sign-in through the stock form, replacing whatever session the browser
  # holds. Customised the login page? Change the three labels here, once.
  #
  # Success is a redirect away from the form; failure re-renders it at the same
  # URL. The URL is what to wait on: under Turbo the submit is a fetch, and a
  # check on the form's fields can run in the moment the body is being swapped.
  def sign_in(user, password:)
    Capybara.reset_sessions!
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"
    raise "sign in as #{user.email} failed: still on the login form" unless has_no_current_path?(new_user_session_path)
  end

  private

  def auto? = ENV["QA_AUTO"].present?

  def say(text) = $stdout.puts(text)

  # One raw key: Enter advances, Esc quits, anything else is ignored. Raw mode
  # needs a terminal; piped input falls back to a line per step, and end of
  # input quits.
  def pause(prompt = "    Enter for the next step, Esc to quit…")
    return sleep(ENV.fetch("QA_AUTO_DELAY", "0.5").to_f) if auto?

    $stdout.print prompt
    loop do
      key = $stdin.tty? ? $stdin.getch : $stdin.gets
      raise Quit if key.nil? || bare_escape?(key)
      break if key.start_with?("\r", "\n")
    end
    $stdout.puts
  end

  # Arrow and function keys also begin with Esc but bring more bytes with them;
  # a lone Esc is the only one that means quit.
  def bare_escape?(key)
    return false unless key == "\e"
    return true unless $stdin.tty? && IO.select([ $stdin ], nil, nil, 0.05)

    $stdin.read_nonblock(16, exception: false)
    false
  end

  def shot_dir = Rails.root.join("tmp/qa_walkthrough", @name.parameterize)

  def screenshot
    FileUtils.mkdir_p(shot_dir)
    save_screenshot(shot_dir.join(format("%02d.png", @step)).to_s)
  end

  def caption_on_screen(text)
    execute_script(<<~JS, text)
      let tip = document.getElementById("qa-walkthrough-caption");
      if (!tip) {
        tip = document.createElement("div");
        tip.id = "qa-walkthrough-caption";
        tip.style.cssText = "position:fixed;left:24px;right:24px;bottom:24px;z-index:99999;padding:16px 20px;" +
          "background:#111827;color:#fff;font:16px/1.45 system-ui,sans-serif;white-space:pre-line;" +
          "border-radius:10px;box-shadow:0 8px 30px rgba(0,0,0,.4)";
        document.body.appendChild(tip);
      }
      tip.textContent = arguments[0];
    JS
  end
end
