# Commands are mirrored to `.cursor/commands/` at generation time, from one source

## Context

Cursor reads slash commands from `.cursor/commands/`, Claude Code from
`.claude/commands/`. The same 19 files have to be in both places in a generated
app, and the product claims to work in either tool.

Three ways to get a file into two directories: commit it twice, symlink one to the
other, or copy at generation time.

## Decision

`templates/.claude/commands/*.md` is the only source. `template.rb` copies each
file twice, once to each destination, in the same phase:

```ruby
WORKFLOW_COMMANDS.each { |command| copy_template_file command }
WORKFLOW_COMMANDS.each do |command|
  copy_template_file command, command.sub(".claude/", ".cursor/")
end
```

The list is a glob over the source directory, so adding a command needs no edit
here.

## Consequences

Accepted:

- **The generated app carries two copies.** Editing one leaves the other stale. A
  buyer who customises `/pr_submit` in `.claude/commands/` has to mirror it, and
  nothing in the app checks that they did.
- **A symlink was not used** because a link committed into the template would not
  survive the copy into a generated app reliably across platforms, and a link
  created in the app is a file type Windows and some editors handle badly.

Gained: in this repo, which is where commands are actually written, there is
exactly one file per command. No sync step, no drift between two committed
copies, and `bin/lint-docs` has one place to check.

## Revisit when

A generated app needs to be able to edit a command once and have both tools see
it. The fix then is a small `bin/sync-commands` in the generated app rather than
changing where the source lives.
