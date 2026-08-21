# frozen_string_literal: true

# Rails Rocket Sheep - Highly Opinionated Rails 8 Template
#
# Usage:
#   rails new myapp --database=postgresql --template=path/to/template.rb
#   rails new myapp --database=mysql      --template=path/to/template.rb
#
# What this template does:
#   - Configures Rails 8 Solid Stack (Queue, Cache, Cable - all database-backed)
#   - Sets up Kamal 2 deployment with PostgreSQL accessory
#   - Adds Devise + Petergate for authentication and authorization
#   - Configures UUID primary keys for all models (PostgreSQL only)
#   - Adds ApplicationService base class with Result pattern
#   - Adds ApplicationForm base class for multi-model form objects
#   - Adds a Data-based registry pattern for fixed variant sets
#   - Adds ViewComponent with ApplicationComponent and four shipped components
#   - Includes generic Stimulus controllers (toggle, modal)
#   - Sets up SEO foundation (sitemap, meta tags, structured data, robots.txt)
#   - Sets up VCR for HTTP testing and Slowpoke for slow-test reporting
#   - Configures Bullet for N+1 detection
#   - Creates comprehensive CLAUDE.md for AI assistants

# When `--template` points at a URL, Rails evaluates this file with `__FILE__`
# set to that URL, so `__dir__` is a URL too. Thor's `find_in_source_paths` only
# ever calls `File.exist?`, so the whole `templates/` tree is unreachable that
# way -- generation dies on the first copy with "Could not find
# config/database.yml.tt in any of your source paths". Clone the repo to a temp
# directory and copy from there instead.
DEFAULT_REPO = "PositiveControl/rails-rocket-sheep"

TEMPLATE_ROOT =
  if __dir__.to_s.start_with?("http://", "https://")
    require "tmpdir"
    require "fileutils"

    owner, repo, ref = __dir__.match(
      %r{\Ahttps?://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)}
    )&.captures || [*DEFAULT_REPO.split("/"), "main"]

    checkout = Dir.mktmpdir("rails-rocket-sheep-")
    at_exit { FileUtils.remove_entry(checkout, true) }

    say "Fetching template files from #{owner}/#{repo} (#{ref})...", :green
    cloned = system(
      "git", "clone", "--depth", "1", "--quiet",
      "--branch", ref, "https://github.com/#{owner}/#{repo}.git", checkout
    )
    unless cloned
      raise Thor::Error,
            "Could not clone https://github.com/#{owner}/#{repo}.git (ref #{ref}). " \
            "Git is required to run this template from a URL. Clone the repo and " \
            "pass a local path to --template instead."
    end

    checkout
  else
    __dir__
  end

# =============================================================================
# Helper Methods
# =============================================================================

# `instance_eval`, not `require`: `source_paths` has to land on this generator's
# singleton class to override Thor::Actions', and adopt.rb needs the same three
# helpers plus the same stamp. See the comment at the top of preamble.rb.
instance_eval(File.read(File.join(TEMPLATE_ROOT, "preamble.rb")), "preamble.rb")

# =============================================================================
# Database Family
# =============================================================================

# Rails already asked this question. `rails new --database=` picked the gem, the
# CI service, and the adapter, so read the answer rather than prompting for it
# again.
#
# Branch on the *family*, not the adapter: mysql2 and trilogy differ in the
# driver and in nothing a convention cares about. The one place the family
# genuinely diverges is primary keys — see
# .agents/adr/0007-database-family-is-chosen-at-generation.md.
DB_CHOICE = options[:database].to_s

DB_ADAPTER =
  case DB_CHOICE
  when "postgresql" then "postgresql"
  when "mysql", "mariadb-mysql" then "mysql2"
  when "trilogy", "mariadb-trilogy" then "trilogy"
  else
    raise Thor::Error, <<~MSG
      This template supports PostgreSQL and MySQL, and was given
      --database=#{DB_CHOICE.empty? ? '(none)' : DB_CHOICE}.

      The Solid Stack runs queue, cache, and cable in separate databases, which
      SQLite can do but no deployment target here is set up for. Generate with
      one of:

        rails new #{app_name} --database=postgresql --template=...
        rails new #{app_name} --database=mysql      --template=...
        rails new #{app_name} --database=trilogy    --template=...

      MariaDB works too (--database=mariadb-mysql / mariadb-trilogy).
    MSG
  end

DB_FAMILY = DB_ADAPTER == "postgresql" ? :postgresql : :mysql
POSTGRESQL = DB_FAMILY == :postgresql

DB_LABEL =
  if POSTGRESQL then "PostgreSQL"
  elsif DB_CHOICE.start_with?("mariadb") then "MariaDB"
  else "MySQL"
  end

# Primary keys are the one convention that cannot be shared. PostgreSQL has a
# native uuid type and gen_random_uuid(); MySQL has neither, and faking it costs
# a char(36) index and a type shim Rails does not ship. MySQL apps get Rails'
# default bigint.
DB_PRIMARY_KEY = POSTGRESQL ? "uuid" : "bigint"

DB_ACCESSORY_IMAGE =
  if POSTGRESQL then "postgres:16"
  elsif DB_LABEL == "MariaDB" then "mariadb:11"
  else "mysql:8.4"
  end

DB_PORT = POSTGRESQL ? 5432 : 3306

say "Database: #{DB_LABEL} (adapter #{DB_ADAPTER}, #{DB_PRIMARY_KEY} primary keys)", :green

# Solid Stack configs are re-copied in after_bundle because Rails 8 runs
# `solid_cache:install solid_queue:install solid_cable:install` after bundling,
# which overwrites whatever the template wrote during the main pass.
SOLID_CONFIGS = %w[
  config/queue.yml
  config/cache.yml
  config/cable.yml
  config/recurring.yml
].freeze

# =============================================================================
# Phase 1: Gem Configuration
# =============================================================================

say "Configuring gems...", :green

# Remove SQLite (we use PostgreSQL)
gsub_file "Gemfile", /gem "sqlite3".*\n/, ""

# Note: Rails 8 already includes solid_cache, solid_queue, solid_cable, kamal, thruster
# We only add gems that aren't in the default Rails 8 Gemfile

# Frontend
gem "tailwindcss-rails"

# Authentication & Authorization
gem "devise"
gem "petergate"

# Data management
gem "discard"                # Soft deletes
gem "paper_trail"            # Audit trail / versioning

# Pagination
gem "pagy", "~> 43.6"

# Templates
gem "slim-rails"
gem "view_component", "~> 4.0"   # UI components with tests

# Email (optional - Resend API)
gem "resend", "~> 1.7"

# Development gems
gem_group :development do
  gem "letter_opener_web", "~> 3.0"
end

gem_group :development, :test do
  gem "pry"
  gem "pry-rails"
  gem "bullet"
  gem "rubocop-rails-omakase", require: false  # Linting
  gem "brakeman", require: false               # Security analysis
end

gem_group :test do
  gem "vcr", "~> 6.0"
  gem "webmock", "~> 3.0"
  # Slow-test reporter. Gem is slowpoke-rb, library is slowpoke — require it
  # explicitly from test/support/slowpoke.rb rather than letting Bundler guess.
  gem "slowpoke-rb", "~> 0.1", require: false
end

# =============================================================================
# Phase 2: Database Configuration
# =============================================================================

say "Configuring multi-database setup...", :green

# Multi-database configuration for Solid Stack
remove_file "config/database.yml"
template_file "config/database.yml.tt"

# Create migration directories for queue/cable/cache
empty_directory "db/queue_migrate"
empty_directory "db/cable_migrate"
empty_directory "db/cache_migrate"

# Configure generators. UUID primary keys are PostgreSQL-only: MySQL has no
# native uuid type, so a MySQL app keeps Rails' default bigint.
# `<<~` strips to column 0, so indent to the 4 spaces the class body uses —
# otherwise every generated app starts with unindented config.
inject_into_file "config/application.rb", after: "class Application < Rails::Application\n" do
  generators = if POSTGRESQL
    <<~RUBY
      # Use UUIDs as primary keys by default
      config.generators do |g|
        g.orm :active_record, primary_key_type: :uuid
      end
    RUBY
  else
    <<~RUBY
      # Primary keys are Rails' default bigint. MySQL has no native uuid type,
      # and a char(36) key costs index size for no gain here.
      config.generators do |g|
        g.orm :active_record
      end
    RUBY
  end

  <<~RUBY.indent(4)
    #{generators.strip}

    # Autoload app/lib for registries and game config
    config.autoload_paths << Rails.root.join("app/lib")

    # ViewComponent: generate a sidecar directory so a component's class,
    # template, and any component-scoped Stimulus controller sit together.
    # Template engine follows config.generators.template_engine, which
    # slim-rails sets to :slim.
    config.view_component.generate.sidecar = true

  RUBY
end

# =============================================================================
# Phase 3: Application Configuration
# =============================================================================

say "Configuring application...", :green

# ApplicationRecord with UUID and implicit ordering
remove_file "app/models/application_record.rb"
template_file "app/models/application_record.rb.tt"

# Solid Stack configuration (queue, cache, cable, recurring) is written in
# after_bundle, not here — see SOLID_CONFIGS above. Writing it now would make
# Rails' own solid_*:install generators prompt the user to overwrite it.

# =============================================================================
# Phase 4: Development Environment
# =============================================================================

say "Configuring development environment...", :green

# Bullet (N+1 detection) and letter_opener_web (email preview).
#
# Both go in a single injection, indented to match the file. Two separate
# `before: /^end\s*$/` injections would not work: the first one writes an
# unindented `end` of its own, which the second injection then matches — so the
# second block lands inside the Bullet `after_initialize` block instead of at
# config level.
inject_into_file "config/environments/development.rb", before: /^end\s*$/ do
  <<~RUBY.indent(2)

    # Bullet N+1 query detection
    config.after_initialize do
      Bullet.enable = true
      Bullet.bullet_logger = true
      Bullet.console = true
      Bullet.rails_logger = true
      Bullet.add_footer = true
    end

    # Email preview in development
    config.action_mailer.delivery_method = :letter_opener_web
    config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
  RUBY
end

# =============================================================================
# Phase 5: Production Environment
# =============================================================================

say "Configuring production environment...", :green

# Configure Solid Cache for production
gsub_file "config/environments/production.rb",
  /config\.cache_store = :solid_cache_store/,
  "config.cache_store = :solid_cache_store"

# =============================================================================
# Phase 6: Deployment Setup
# =============================================================================

say "Setting up Kamal deployment...", :green

# Kamal configuration
template_file "config/deploy.yml.tt"

# Docker configuration
template "Dockerfile.tt", "Dockerfile", force: true

# Docker entrypoint script (Rails 8 ships its own — ours runs migrations)
template_file "bin/docker-entrypoint.tt", force: true
chmod "bin/docker-entrypoint", 0755

# macOS-friendly test script
copy_template_file "bin/test"
chmod "bin/test", 0755

# Kamal secrets. The filename `templates/kamal-secrets.tt` is load-bearing and
# must not be renamed: Rails' own generator re-renders it after bundling.
# `Rails::Generators::AppBase#run_kamal` runs `bundle exec kamal init` and then
#
#   template "kamal-secrets.tt", ".kamal/secrets", force: true
#
# which resolves through `find_in_source_paths` — and `source_paths` is ours, so
# railties' copy is unreachable and only a file of that name in `templates/`
# satisfies it. Without one, every generation that bundles dies there, and
# everything after it (Tailwind, the Solid configs, the devise initializer,
# `bin/jobs`, `Procfile.dev`) never runs. `--skip-bundle` hides it, because
# `run_kamal` returns early when there is no bundle.
#
# So this is written once, here, and railties' re-render is a no-op on it. The
# MySQL branch emits both passwords: the official image refuses to initialise
# without a root password, and the app connects as MYSQL_USER.
empty_directory ".kamal"
template_file "kamal-secrets.tt", ".kamal/secrets"

# =============================================================================
# Phase 7: Service Objects & Patterns
# =============================================================================

say "Adding service object patterns...", :green

# ApplicationService base class
copy_template_file "app/services/application_service.rb"

# ApplicationForm base class (multi-model / non-AR forms)
copy_template_file "app/forms/application_form.rb"

# Canonical registry — Data objects, fetch-based lookup
copy_template_file "app/lib/plan_registry.rb"

# App-wide constants (branding, flags, limits, timing)
copy_template_file "app/lib/app_config.rb"

# =============================================================================
# Phase 8: Frontend Setup
# =============================================================================

say "Setting up frontend...", :green

# Generic Stimulus controllers
copy_template_file "app/javascript/controllers/toggle_controller.js"
copy_template_file "app/javascript/controllers/modal_controller.js"

# Helpers
copy_template_file "app/helpers/progress_bar_helper.rb"

# ViewComponent base class plus the four components every app ends up needing.
# Each ships with a unit test — see test/components/.
copy_template_file "app/components/application_component.rb"

%w[alert flash error_summary empty_state].each do |component|
  copy_template_file "app/components/#{component}_component.rb"
  copy_template_file "app/components/#{component}_component/#{component}_component.html.slim"
  copy_template_file "test/components/#{component}_component_test.rb"
end

# Pagy is installed but Rails does not wire it up. Do it here so "every index
# paginates" is a rule someone can actually follow — see docs/rules/pagination.md.
#
# Pagy 43 replaced the old Pagy::Backend / Pagy::Frontend pair with a single
# Pagy::Method module. The view helpers now live on the Pagy instance
# (@pagy.series_nav), so ApplicationHelper needs no include at all.
inject_into_class "app/controllers/application_controller.rb", "ApplicationController" do
  "  include Pagy::Method\n\n"
end

# =============================================================================
# Phase 9: SEO Foundation
# =============================================================================

say "Setting up SEO foundation...", :green

# robots.txt with sensible defaults (Rails 8 ships a minimal one)
copy_template_file "public/robots.txt", force: true

# Structured data helper (jsonld_tag + iso8601_duration)
copy_template_file "app/helpers/structured_data_helper.rb"

# SEO integration tests
copy_template_file "test/integration/seo_test.rb"

# Lighthouse CI workflow + budget
copy_template_file ".github/workflows/lighthouse.yml"
copy_template_file ".github/lighthouse-budget.json"


# =============================================================================
# Phase 10: Testing Setup
# =============================================================================

say "Configuring testing...", :green

# VCR support
copy_template_file "test/support/vcr.rb"

# Slowpoke slow-test reporting
copy_template_file "test/support/slowpoke.rb"

# Generator override: stock fixtures emit two identical placeholder records,
# which violate any unique index (notably Devise's email) on first test run.
copy_template_file "lib/templates/test_unit/model/fixtures.yml"

# Idempotent seed creating an admin user with a generated password. Replaces
# the empty db/seeds.rb Rails ships, so a fresh app has something to log in as.
copy_template_file "db/seeds.rb", nil, force: true

# Update test_helper to require VCR
inject_into_file "test/test_helper.rb", before: /^class ActiveSupport::TestCase/ do
  <<~RUBY
  # VCR for HTTP request recording
  require_relative "support/vcr"

  # Slowpoke — reports tests slower than the threshold after each run
  require_relative "support/slowpoke"

  RUBY
end

# =============================================================================
# Phase 11: Code Quality
# =============================================================================

say "Setting up code quality tools...", :green

# Rubocop configuration (Rails 8 ships its own omakase file)
copy_template_file ".rubocop.yml", force: true

# =============================================================================
# Phase 12: Alignment Layer
# =============================================================================

# Conventions, rules, the doc canon, workflow commands, hooks, and the PR/issue
# templates. They live in adopt.rb rather than here because an app generated
# without this template installs exactly the same set, with
# `bin/rails app:template LOCATION=.../adopt.rb`, and a second copy of the list
# would drift. `instance_eval` rather than Thor's `apply`: `apply` resolves its
# argument through `find_in_source_paths` and would look for adopt.rb inside
# templates/.
instance_eval(File.read(File.join(TEMPLATE_ROOT, "adopt.rb")), "adopt.rb")

# =============================================================================
# Phase 13: Routes Configuration
# =============================================================================

say "Configuring routes and home page...", :green

# Create HomeController with sitemap
create_file "app/controllers/home_controller.rb", <<~RUBY
  class HomeController < ApplicationController
    def index
    end

    def sitemap
      require "builder"
      expires_in 1.hour, public: true

      builder = Builder::XmlMarkup.new(indent: 2)
      builder.instruct!

      xml = builder.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do |urlset|
        # Homepage
        urlset.url do |url|
          url.loc root_url
          url.changefreq "daily"
          url.priority "1.0"
        end

        # Add your pages here — see docs/sop/add-seo-to-a-page.md
      end

      render xml: xml
    end
  end
RUBY

# Create home view directory and view
empty_directory "app/views/home"
# Note: unquoted heredoc — app_name is interpolated now, at generation time.
# The Devise helpers are guarded because no User model exists until the
# developer runs `rails g devise User`; without the guard the home page raises
# on first boot.
create_file "app/views/home/index.html.slim", <<~SLIM
  .min-h-screen.bg-gradient-to-br.from-indigo-900.via-purple-900.to-pink-800.flex.items-center.justify-center
    .text-center.p-8
      / Rocket Sheep Logo
      .text-8xl.mb-6.animate-bounce
        span.inline-block.transform.-rotate-45 🚀
        span.inline-block.ml-2 🐑

      h1.text-5xl.font-bold.text-white.mb-2
        | #{app_name.titleize}

      p.text-purple-200.text-lg.mb-2
        | Powered by Rails Rocket Sheep

      p.text-purple-300.text-sm.mb-8
        | Rails 8 • Solid Stack • Kamal Deploy

      .space-x-4
        - if respond_to?(:user_signed_in?) && user_signed_in?
          .text-purple-200.mb-4
            | Welcome back!
          = link_to "Sign Out", destroy_user_session_path, data: { turbo_method: :delete }, class: "px-6 py-3 bg-white/10 text-white rounded-lg hover:bg-white/20 backdrop-blur border border-white/20 transition"
        - elsif respond_to?(:new_user_session_path)
          = link_to "Sign In", new_user_session_path, class: "px-6 py-3 bg-white text-purple-900 font-semibold rounded-lg hover:bg-purple-100 transition"
          = link_to "Sign Up", new_user_registration_path, class: "px-6 py-3 bg-white/10 text-white rounded-lg hover:bg-white/20 backdrop-blur border border-white/20 transition"
        - else
          p.text-purple-200.text-sm
            | Run <code class="font-mono">rails g devise User</code> to enable authentication

      .mt-12.text-purple-400.text-sm
        | Ready to build something amazing
SLIM

# Replace routes file entirely
remove_file "config/routes.rb"
create_file "config/routes.rb", <<~RUBY
  Rails.application.routes.draw do
    # Health check endpoint for Kamal
    get "up" => "rails/health#show", as: :rails_health_check

    # SEO
    get "sitemap.xml", to: "home#sitemap", as: :sitemap, defaults: { format: "xml" }

    # Email preview in development
    if Rails.env.development?
      mount LetterOpenerWeb::Engine, at: "/letter_opener"
    end

    # Root path
    root "home#index"
  end
RUBY

# =============================================================================
# Phase 14: Git Configuration
# =============================================================================

say "Configuring git...", :green

# Add to .gitignore
# Only what this generator installs. The ignores that belong to the alignment
# layer (agent scratch, local Claude settings, the update script's checkout)
# are appended by adopt.rb, so they travel with the layer into an app that
# adopts it later.
append_to_file ".gitignore", <<~GITIGNORE

  # Kamal secrets
  .kamal/secrets

  # Environment files
  .env*
  !.env.example

  # IDE
  .idea/
  .vscode/
GITIGNORE

# =============================================================================
# After Bundle
# =============================================================================

after_bundle do
  say "Running post-bundle setup...", :green

  # Note: on PostgreSQL 13+, gen_random_uuid() is built in — no pgcrypto needed.
  # MySQL needs nothing here at all; its keys are bigint.

  # Rails 8 runs solid_cache/solid_queue/solid_cable installers after bundling,
  # which overwrite the Solid Stack configs written during the main pass.
  # Re-apply ours now that those generators have finished.
  say "Restoring Solid Stack configuration...", :yellow
  SOLID_CONFIGS.each { |config| copy_template_file config, force: true }

  # Install Devise
  say "Installing Devise...", :yellow
  generate "devise:install"

  # Configure Devise for Turbo
  inject_into_file "config/initializers/devise.rb", after: "Devise.setup do |config|\n" do
    <<~RUBY
    # Turbo compatibility
    config.navigational_formats = ['*/*', :html, :turbo_stream]

    RUBY
  end

  # Inject SEO meta tags into layout
  say "Adding SEO meta tags to layout...", :yellow
  inject_into_file "app/views/layouts/application.html.erb",
    after: "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n" do
    <<~ERB.indent(4)
      <meta name="description" content="<%= content_for?(:meta_description) ? yield(:meta_description) : '#{app_name.titleize} — built with Rails.' %>">
      <link rel="canonical" href="<%= content_for?(:canonical_url) ? yield(:canonical_url) : request.original_url.split('?').first %>">
    ERB
  end

  # Add WebSite JSON-LD to the layout.
  #
  # Do not inject a `yield :head` here — Rails' own layout already has one, and a
  # second would render every `content_for :head` block twice.
  inject_into_file "app/views/layouts/application.html.erb",
    before: "    <%= stylesheet_link_tag" do
    <<~ERB.indent(4)
      <script type="application/ld+json">
      {"@context":"https://schema.org","@type":"WebSite","name":"#{app_name.titleize}","url":"<%= root_url %>"}
      </script>
    ERB
  end

  # Render the flash through FlashComponent instead of leaving it unhandled
  inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do
    "    <%= render FlashComponent.new(flash: flash) %>\n"
  end

  # Install PaperTrail
  say "Installing PaperTrail...", :yellow
  generate "paper_trail:install", "--with-changes"

  # Install Tailwind
  say "Installing Tailwind CSS...", :yellow
  rails_command "tailwindcss:install"

  # Create and migrate database
  say "Setting up database...", :yellow
  rails_command "db:create"
  rails_command "db:migrate"

  # Initialize git repository
  git :init
  git add: "."
  git commit: %Q{ -m "Initial commit from Rails Rocket Sheep template" }

  say ""
  say "=" * 60, :green
  say " Rails Rocket Sheep template applied successfully!", :green
  say "=" * 60, :green
  say ""
  say "Next steps:", :yellow
  say "  1. Create your User model:"
  say "     rails g devise User"
  say ""
  say "  2. Configure config/deploy.yml with your server details"
  say ""
  say "  3. Set up secrets in .kamal/secrets"
  say ""
  say "  4. Update SEO URLs:"
  say "     - public/robots.txt (Sitemap URL)"
  say "     - .github/workflows/lighthouse.yml (production URL)"
  say ""
  say "  5. Start developing:"
  say "     bin/dev"
  say ""
  say "  6. Deploy when ready:"
  say "     kamal setup && kamal deploy"
  say ""
end
