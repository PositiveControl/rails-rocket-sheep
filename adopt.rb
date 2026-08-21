# frozen_string_literal: true

# adopt.rb — installs the Rails Rocket Sheep alignment layer.
#
# Two callers, one source of truth for what the alignment layer *is*:
#
#   template.rb                  evaluates this file as its documentation phase,
#                                so a newly generated app gets the layer.
#
#   an app generated without it  bin/rails app:template LOCATION=/path/to/adopt.rb
#
# It writes conventions, rules, workflow commands, the doc canon, hooks, and the
# PR/issue templates. It never touches Gemfile, app/, config/, or db/ — see
# .agents/adr/0006-adoption-installs-the-alignment-layer-only.md for what that
# buys and what it costs.
#
# Every path this file names is also the manifest `bin/rocket-sheep-update`
# reads, out of the template checkout, to decide which files a later update is
# allowed to merge. Adding a copy here is what makes a file updatable; there is
# no second list.

ADOPT_STANDALONE = !defined?(TEMPLATE_ROOT)

if ADOPT_STANDALONE
  # `rails app:template LOCATION=...` evaluates this file with __FILE__ set to
  # the path it was given, so the repo is already on disk and templates/ is
  # reachable from __dir__. A URL LOCATION is not supported here: unlike
  # template.rb, this file has no reason to clone itself, and the checkout is
  # what `bin/rocket-sheep-update` wants you to keep anyway.
  if __dir__.to_s.start_with?("http://", "https://")
    raise Thor::Error,
          "adopt.rb cannot run from a URL — it copies the templates/ tree next to it. " \
          "Clone https://github.com/PositiveControl/rails-rocket-sheep and pass a local " \
          "path: bin/rails app:template LOCATION=/path/to/rails-rocket-sheep/adopt.rb"
  end

  TEMPLATE_ROOT = __dir__
  instance_eval(File.read(File.join(TEMPLATE_ROOT, "preamble.rb")), "preamble.rb")

  say "Adopting the Rails Rocket Sheep alignment layer (commit #{TEMPLATE_SHA})...", :green
  say ""
  say "Nothing outside the alignment layer is touched: no Gemfile, no app/, no", :yellow
  say "config/, no db/. Files you already have are offered as a conflict — press", :yellow
  say "d to diff before you decide.", :yellow
  say ""
end

# =============================================================================
# Conventions
# =============================================================================

say "Creating documentation...", :green

# CLAUDE.md for the app. Lives at templates/CLAUDE.md.tt so it is unmistakably
# an artifact this template writes, not this repo's own agent instructions —
# the repo's CLAUDE.md sits at the root and describes how to work on
# template.rb itself. It carries the origin stamp, which is what
# bin/rocket-sheep-update reads later.
template_file "CLAUDE.md.tt"

# Doc canon. Every workflow command in .claude/commands reads
# and writes these paths, so the names are load-bearing — don't rename them
# without updating the commands.
#
#   docs/plans   design docs        (/feature_plan writes here)
#   docs/adr     decisions, one per file (/domain_model writes here)
#   docs/system  architecture state (/pr_submit completes placeholders here)
#   docs/sop     procedures         (/pr_submit completes placeholders here)
#   docs/qa      manual test guides (/pr_qa writes here)
empty_directory "docs"
empty_directory "docs/plans"
empty_directory "docs/qa"

template_file "docs/system/models.md.tt"
copy_template_file "docs/system/vocabulary.md"

# One decision per file, numbered, newest last. Globbed for the same reason the
# rules are: adding a decision must not mean editing a manifest, or the ADR that
# skips the edit is one adoption never installs and no update can reach.
ADR_FILES = Dir.glob(File.join(TEMPLATE_ROOT, "templates/docs/adr/*.md"))
               .map { |path| "docs/adr/#{File.basename(path)}" }.freeze

empty_directory "docs/adr"
ADR_FILES.each { |adr| copy_template_file adr }

copy_template_file "docs/sop/harden-a-kamal-server.md"
copy_template_file "docs/sop/extract-database-and-storage.md"
copy_template_file "docs/sop/beads-setup.md"
copy_template_file "docs/sop/find-slow-tests.md"
copy_template_file "docs/sop/add-seo-to-a-page.md"
copy_template_file "docs/sop/update-from-the-template.md"

# Sharded conventions. One rule per file with frontmatter (applies_to globs,
# trigger keywords); docs/rules/INDEX.md routes to them. Plain markdown so any
# agent can use it — no harness-specific loading. An agent reads the index and
# then only the rules that match the file it is editing.
RULE_FILES = Dir.glob(File.join(TEMPLATE_ROOT, "templates/docs/rules/*.md"))
                .map { |path| "docs/rules/#{File.basename(path)}" }.freeze

empty_directory "docs/rules"
RULE_FILES.each { |rule| copy_template_file rule }

# =============================================================================
# Agent Workflow
# =============================================================================

say "Installing agent workflow commands...", :green

# The slash commands driving the lifecycle:
#   /pick → /feature_plan → /task_plan → /implement → /pr_submit → merge
# Stack tokens (test/lint/scan commands, default branch) are pre-filled for
# this stack. Repo and board tokens remain for `/workflow_setup` to fill.
WORKFLOW_COMMANDS = Dir.glob(File.join(TEMPLATE_ROOT, "templates/.claude/commands/*.md"))
                       .map { |path| ".claude/commands/#{File.basename(path)}" }.freeze

empty_directory ".claude/commands"
WORKFLOW_COMMANDS.each { |command| copy_template_file command }

# Mirror the same files to .cursor/commands/, which Cursor reads as slash
# commands. Same source, second destination — never a fork, or the two copies
# drift and the tool-neutrality claim stops being true.
empty_directory ".cursor/commands"
WORKFLOW_COMMANDS.each do |command|
  copy_template_file command, command.sub(".claude/", ".cursor/")
end

# Cursor project rules. Like AGENTS.md, a pointer to CLAUDE.md rather than a
# second copy of the conventions.
copy_template_file ".cursor/rules/conventions.mdc"

# Project permissions + hooks. The allowlist covers this template's own
# binstubs and read-only git/gh operations, so an agent stops asking to run
# `bin/test`. The deny list keeps credentials out of the context window and
# blocks history-destroying git commands.
copy_template_file ".claude/settings.json"

# Hooks turn two CLAUDE.md conventions into enforcement rather than advice:
# RuboCop on edited Ruby, and the Slim/Tailwind bracket pitfall. The Stop hook
# catches Draft doc placeholders left behind at the end of a session.
copy_template_file "bin/hooks/post_edit"
copy_template_file "bin/hooks/session_end"
chmod "bin/hooks/post_edit", 0755
chmod "bin/hooks/session_end", 0755

# Tool-neutral pointer to CLAUDE.md, for agents that look for AGENTS.md
copy_template_file "AGENTS.md"

# PR and issue templates. /pr_submit writes a correct PR body on its own; these
# carry the same conventions into PRs and issues opened by hand, which is where
# they otherwise get dropped. The PR template is tier-neutral — it explains when
# to add `Closes #` rather than hardcoding it, since tier `beads` must not.
# Issue forms put the <=5-acceptance-criteria sizing rule at the point of
# creation, which is where sizing actually gets decided.
copy_template_file ".github/PULL_REQUEST_TEMPLATE.md"
empty_directory ".github/ISSUE_TEMPLATE"
copy_template_file ".github/ISSUE_TEMPLATE/feature.yml"
copy_template_file ".github/ISSUE_TEMPLATE/bug.yml"
copy_template_file ".github/ISSUE_TEMPLATE/config.yml"

# Stacked-PR footer generator, called by /pr_submit
copy_template_file "bin/pr-stack"
chmod "bin/pr-stack", 0755

# Reconciles this layer with a newer template, three-way, from the stamp in
# CLAUDE.md. It is inside the layer it updates, so it updates itself.
copy_template_file "bin/rocket-sheep-update"
chmod "bin/rocket-sheep-update", 0755

# Local scratch: task files and segue threads. Gitignored — these are working
# state for resuming a session, not artifacts to review.
empty_directory ".llm/tasks"
empty_directory ".llm/threads"
copy_template_file ".llm/tasks/task_template.md"
create_file ".llm/threads/.gitkeep", ""

# Documentation index — committed docs only. /feature_plan adds placeholder
# entries, /pr_submit completes-or-deletes them and checks for dead links.
copy_template_file ".llm/README.md"

# Workflow spec: lifecycle diagrams, gates, sizing rules
copy_template_file "WORKFLOW.md"

# Agent scratch and local settings have to be ignored wherever this layer
# lands, so the rule travels with the layer rather than with the generator.
# Appended once: adopting twice must not double the block.
gitignore = File.join(destination_root, ".gitignore")
create_file ".gitignore", "" unless File.exist?(gitignore)

unless File.read(gitignore).include?(".llm/tasks/*")
  append_to_file ".gitignore", <<~GITIGNORE

    # Claude Code — local settings only. The workflow commands in
    # .claude/commands/ are tracked deliberately: they are shared team
    # convention, and every command assumes the others are present.
    .claude/settings.local.json
    .claude/*.local.json

    # Agent scratch — task files and segue threads are per-developer working
    # state for resuming a session, not reviewable artifacts. The task template
    # itself is shared convention, so it stays tracked.
    .llm/tasks/*
    !.llm/tasks/task_template.md
    .llm/threads/*
    !.llm/threads/.gitkeep

    # Template checkout cached by bin/rocket-sheep-update
    tmp/rocket-sheep-template/
  GITIGNORE
end

if ADOPT_STANDALONE
  say ""
  say "=" * 60, :green
  say " Alignment layer adopted (template commit #{TEMPLATE_SHA})", :green
  say "=" * 60, :green
  say ""
  say "Next steps:", :yellow
  say "  1. Review the diff. Your CLAUDE.md, AGENTS.md and .gitignore were the"
  say "     only files with a chance of already existing."
  say ""
  say "  2. Fill the repo and board tokens the commands still carry:"
  say "     /workflow_setup"
  say ""
  say "  3. Read WORKFLOW.md, then docs/rules/INDEX.md."
  say ""
  say "  4. The rules and SOPs document patterns this file did not install"
  say "     (ApplicationService, ApplicationForm, registries, the SEO helper,"
  say "     Slim, ViewComponent). Adopt each pattern when you next need it, or"
  say "     delete the rule — a rule pointing at a class you do not have is"
  say "     worse than no rule."
  say ""
  say "  5. Later, pull template fixes in three-way:"
  say "     bin/rocket-sheep-update --check"
  say ""
end
