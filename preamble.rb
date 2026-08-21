# frozen_string_literal: true

# preamble.rb — the helpers and stamp shared by the two entry points.
#
#   template.rb  generates a new app
#   adopt.rb     installs the alignment layer into an app that already exists
#
# Both `instance_eval` this file after resolving TEMPLATE_ROOT. It is not a
# library and is never `require`d: the `def`s below have to land on the
# generator's singleton class so `source_paths` overrides Thor::Actions'. A
# `require` or `load` would define them on Object, where Thor's own method wins
# and every copy fails to find its source.

def source_paths
  [File.join(TEMPLATE_ROOT, "templates"), TEMPLATE_ROOT]
end

def template_file(source, destination = nil, **options)
  destination ||= source.sub(/\.tt$/, "")
  template source, destination, **options
end

def copy_template_file(source, destination = nil, **options)
  destination ||= source
  copy_file source, destination, **options
end

# The commit this app's alignment layer came from. A generated app is a copy,
# not a dependency: nothing here tracks the template, and no rule corpus is
# fetched behind your back. Recording the origin is what makes a stale
# convention diagnosable, and what `bin/rocket-sheep-update` reads to find the
# range of template history to reconcile against.
TEMPLATE_SHA =
  begin
    sha = IO.popen(
      ["git", "-C", TEMPLATE_ROOT.to_s, "rev-parse", "--short", "HEAD"],
      err: File::NULL, &:read
    ).to_s.strip
    sha.empty? ? "unknown" : sha
  rescue StandardError
    "unknown" # no git, or a tarball with no history -- never fail generation for a stamp
  end

TEMPLATE_GENERATED_ON = Time.now.strftime("%Y-%m-%d")
