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
#   - Adds ApplicationService base class with a three-state Result
#   - Adds ApplicationForm base class for multi-model form objects (HTML mode)
#   - With --api: Doorkeeper, rack-cors, and the serializer / contract / filter /
#     cursor base classes, an RFC 9457 problem helper, an idempotency table, and
#     an OpenAPI document generated from the request tests
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

# API mode (ADR 0009). By the time this runs, `rails new --api` has already skipped
# the view and asset tooling and thinned the middleware stack; what is left is
# choosing the gems, the base classes the API rules name, and — through adopt.rb,
# which reads config.api_only — which half of the rule corpus ships.
API = options[:api].present?

say "Mode: #{API ? 'API-only — JSON, no view layer' : 'server-rendered HTML'}", :green

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
gem "tailwindcss-rails" unless API

# Authentication & Authorization
gem "devise"
gem "petergate"

if API
  # OAuth 2 with server-side revocation. Chosen for what it does not have to be
  # replaced by later — docs/rules/api-auth.md.
  gem "doorkeeper", "~> 5.7"
  # The client is a separate origin, so this is load-bearing — docs/rules/cors.md.
  gem "rack-cors"
end

# Data management
gem "discard"                # Soft deletes
gem "paper_trail"            # Audit trail / versioning

unless API
  # Pagination. API mode paginates by cursor instead — docs/rules/cursor-pagination.md.
  gem "pagy", "~> 43.6"

  # Templates
  gem "slim-rails"
  gem "view_component", "~> 4.0"   # UI components with tests
end

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

  # ViewComponent is not installed in API mode, and a setting for a gem that is
  # absent raises on boot rather than being ignored.
  components = if API
    ""
  else
    <<~RUBY.strip
      # ViewComponent: generate a sidecar directory so a component's class,
      # template, and any component-scoped Stimulus controller sit together.
      # Template engine follows config.generators.template_engine, which
      # slim-rails sets to :slim.
      config.view_component.generate.sidecar = true
    RUBY
  end

  <<~RUBY.indent(4)
    #{generators.strip}

    # Autoload app/lib for registries and, in API mode, the cursor
    config.autoload_paths << Rails.root.join("app/lib")

    #{components}
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

# A CI job that needs the database. The service container follows the database
# family, so these workflows are written at generation rather than shipped as
# static files; every drift gate that runs the suite goes through here.
def database_workflow(title, job, final_steps)
  <<~YAML
    name: #{title}

    on: [ push, pull_request ]

    jobs:
      #{job}:
        runs-on: ubuntu-latest

        services:
          db:
            image: #{DB_ACCESSORY_IMAGE}
            env:
              #{POSTGRESQL ? "POSTGRES_PASSWORD: postgres" : "MYSQL_ROOT_PASSWORD: root"}
            ports:
              - #{DB_PORT}:#{DB_PORT}
            options: >-
              --health-cmd "#{POSTGRESQL ? 'pg_isready' : 'mysqladmin ping'}"
              --health-interval 10s --health-timeout 5s --health-retries 5

        env:
          RAILS_ENV: test
          DATABASE_URL: #{POSTGRESQL ? "postgres://postgres:postgres@localhost:#{DB_PORT}" : "mysql2://root:root@127.0.0.1:#{DB_PORT}"}

        steps:
          - uses: actions/checkout@v4

          - uses: ruby/setup-ruby@v1
            with:
              bundler-cache: true

          - run: bin/rails db:prepare

    #{final_steps.indent(6).rstrip}
  YAML
end

# Every SQL shape the suite emits has a reviewed line in db/queries.yml, and CI
# fails on one it does not know — docs/rules/query-ledger.md. The recorder that
# feeds it is copied with the test support files.
copy_template_file "lib/tasks/query_ledger.rake"
create_file ".github/workflows/query-ledger.yml", database_workflow("Query ledger", "queries", <<~YAML)
  # Runs the suite with the recorder armed and fails on a shape db/queries.yml
  # lacks, or a review left empty. Whether the review line is right is the PR
  # reviewer's call; this only asserts that someone wrote one.
  - run: bin/rails db:queries:check
YAML

if API
  # The seven directories an API app gets — docs/rules/pattern-budget.md.
  copy_template_file "app/serializers/application_serializer.rb"
  copy_template_file "app/contracts/application_contract.rb"
  copy_template_file "app/filters/application_filter.rb"
  copy_template_file "app/lib/cursor.rb"
  copy_template_file "app/controllers/api/v1/base_controller.rb"
  copy_template_file "app/models/idempotent_request.rb"
  # force, because `rails new --api` has already written a commented-out sample at
  # this path. Without it an interactive generation stops and asks the user whether
  # to keep the file the template deliberately came here to write.
  copy_template_file "config/initializers/cors.rb", nil, force: true
  copy_template_file "lib/tasks/api_contract.rake"

  # The gate that makes "generated from the request tests" a promise rather than a
  # preference — docs/rules/openapi-contract.md.
  create_file ".github/workflows/api-contract.yml", database_workflow("API contract", "contract", <<~YAML)
    # Regenerates from the request tests and diffs against the committed copy.
    # A stale openapi.yaml fails here rather than reaching a client.
    - run: bin/rails api:contract:check
  YAML
else
  # ApplicationForm base class (multi-model / non-AR forms)
  copy_template_file "app/forms/application_form.rb"
end

# Canonical registry — Data objects, fetch-based lookup
copy_template_file "app/lib/plan_registry.rb"

# App-wide constants (branding, flags, limits, timing)
copy_template_file "app/lib/app_config.rb"

# =============================================================================
# Phase 8: Frontend Setup
# =============================================================================

say "Setting up frontend...", :green

# Nothing in this phase exists in API mode: no asset pipeline, no components, no
# Stimulus, and pagination is by cursor rather than Pagy.
unless API

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

end # unless API

# =============================================================================
# Phase 9: SEO Foundation
# =============================================================================

# SEO is a property of pages, and an API serves none. The client repo owns it.
if API
  say "Skipping SEO foundation — no pages to describe", :yellow
else

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

end # if API


# =============================================================================
# Phase 10: Testing Setup
# =============================================================================

say "Configuring testing...", :green

# VCR support
copy_template_file "test/support/vcr.rb"

# Slowpoke slow-test reporting
copy_template_file "test/support/slowpoke.rb"

# Records the SQL shapes application code emits, so db/queries.yml is a build
# output — docs/rules/query-ledger.md. Inert unless QUERY_LEDGER_OUT is set.
copy_template_file "test/support/query_ledger.rb"

if API
  # assert_problem and a token-per-scope helper — docs/rules/api-testing.md.
  copy_template_file "test/support/api_helpers.rb"
  # Records what the request tests exercise, so the contract is a build output —
  # docs/rules/openapi-contract.md.
  copy_template_file "test/support/api_contract.rb"
end

# Generator override: stock fixtures emit two identical placeholder records,
# which violate any unique index (notably Devise's email) on first test run.
copy_template_file "lib/templates/test_unit/model/fixtures.yml"

# Idempotent seed creating an admin user with a generated password. Replaces
# the empty db/seeds.rb Rails ships, so a fresh app has something to log in as.
copy_template_file "db/seeds.rb", nil, force: true

# Update test_helper to require VCR.
#
# Anchored on the `rails/test_help` require, not on the TestCase declaration:
# Rails 8.1 generates `module ActiveSupport` with a nested `class TestCase`, and an
# anchor on `class ActiveSupport::TestCase` matches nothing. inject_into_file then
# prints "File unchanged!" and generation continues, so the support files shipped
# and were never loaded — VCR configured nothing and WebMock blocked nothing.
inject_into_file "test/test_helper.rb", after: %(require "rails/test_help"\n) do
  <<~RUBY
  # VCR for HTTP request recording
  require_relative "support/vcr"

  # Slowpoke — reports tests slower than the threshold after each run
  require_relative "support/slowpoke"

  # Arms the query ledger recorder when QUERY_LEDGER_OUT is set; inert otherwise
  require_relative "support/query_ledger"

  RUBY
end

if API
  inject_into_file "test/test_helper.rb", after: %(require "rails/test_help"\n) do
    <<~RUBY
    # assert_problem, api_headers
    require_relative "support/api_helpers"

    # Arms the OpenAPI recorder when OPENAPI_OUT is set; inert otherwise
    require_relative "support/api_contract"

    RUBY
  end
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

say "Configuring routes...", :green

if API
  remove_file "config/routes.rb"
  create_file "config/routes.rb", <<~RUBY
    Rails.application.routes.draw do
      # Health check endpoint for Kamal
      get "up" => "rails/health#show", as: :rails_health_check

      # OAuth 2 token and authorization endpoints
      use_doorkeeper

      # Every route lives in a version namespace, with no exceptions — not a
      # health check, not a webhook, not "just internally". The one that escapes
      # is the one an external client finds. See docs/rules/api-versioning.md.
      namespace :api do
        namespace :v1 do
          # resources :items, only: [ :index, :show, :create, :update ]
        end
      end

      # Devise, once `rails g devise User` has run. Its generator writes
      # `devise_for :users` at the top of this file; replace that line with this
      # one, so password reset, confirmation and unlock live under the version
      # prefix and inside the CORS policy. Sessions are skipped because Doorkeeper
      # issues the tokens — docs/rules/api-auth.md.
      #
      # devise_for :users, path: "api/v1/users", skip: [ :sessions ]

      # Email preview in development
      if Rails.env.development?
        mount LetterOpenerWeb::Engine, at: "/letter_opener"
      end
    end
  RUBY
else

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

end # if API

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

  # Devise's navigational formats decide when it redirects rather than answering
  # with a status. An API has nowhere to redirect to.
  inject_into_file "config/initializers/devise.rb", after: "Devise.setup do |config|\n" do
    if API
      <<~RUBY
      # API-only: never redirect, always answer with a status
      config.navigational_formats = []

      RUBY
    else
      <<~RUBY
      # Turbo compatibility
      config.navigational_formats = ['*/*', :html, :turbo_stream]

      RUBY
    end
  end

  # Everything from here to PaperTrail edits the HTML layout, which an API app
  # does not have.
  unless API

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

  end # unless API

  # Install PaperTrail
  say "Installing PaperTrail...", :yellow
  generate "paper_trail:install", "--with-changes"

  unless API
    say "Installing Tailwind CSS...", :yellow
    rails_command "tailwindcss:install"
  end

  if API
    say "Installing Doorkeeper...", :yellow
    generate "doorkeeper:install"
    generate "doorkeeper:migration"

    # Coarse scopes, about capability rather than identity — a scope per endpoint
    # is a permission system pretending to be a scope list.
    inject_into_file "config/initializers/doorkeeper.rb", after: "Doorkeeper.configure do\n" do
      <<~RUBY
        # docs/rules/api-auth.md
        default_scopes  :read
        optional_scopes :write

        # Raise instead of rendering, so an auth failure goes through the app's own
        # problem-document boundary rather than Doorkeeper's HTML response. Flipping
        # this back gives the app a second error format.
        handle_auth_errors :raise

        # A first-party browser client has no login page to be redirected to, so it
        # gets its token with the password grant as a public client. Uncomment to
        # enable it; `bin/rails db:seed` creates the client application. The
        # authorization-code flow stays available for third parties.
        # See docs/rules/api-auth.md.
        #
        # grant_flows %w[password authorization_code]
        #
        # resource_owner_from_credentials do |_routes|
        #   user = User.find_by(email: params[:username])
        #   user if user&.valid_password?(params[:password])
        # end

      RUBY
        .indent(2) # inside `Doorkeeper.configure do`, where RuboCop expects the comment before `orm` indented
    end

    # Doorkeeper ships an authenticator whose body raises until it is wired up.
    # Replace the raise, not the block: Doorkeeper puts explanatory comments
    # between it and the `end`, and a regex that assumed otherwise left the raise
    # in place and said nothing. The body only runs at request time, so this is
    # safe before `rails g devise User`.
    gsub_file "config/initializers/doorkeeper.rb",
              /^\s*raise "Please configure doorkeeper resource_owner_authenticator.*$/,
              "    current_user || warden.authenticate!(scope: :user)"

    # Doorkeeper's migration writes `t.references :resource_owner` with no type,
    # which emits a bigint. On PostgreSQL this app's keys are uuid, so a uuid
    # resource owner id casts to a meaningless integer, `User.find_by` returns
    # nil, and authorization appears to succeed with no current user. This is the
    # failure docs/rules/database-conventions.md warns about, committed by a
    # generator this template does not own.
    if POSTGRESQL
      Dir["db/migrate/*_create_doorkeeper_tables.rb"].each do |migration|
        gsub_file migration, "t.references :resource_owner,", "t.references :resource_owner, type: :uuid,"
      end
    end

    say "Adding the idempotency table...", :yellow

    # Doorkeeper's generator just wrote migrations, and a hand-rolled timestamp
    # collides with them whenever both land in the same second — which is most of
    # the time. Take one past the highest version present instead.
    latest = Dir["db/migrate/*.rb"].map { |file| File.basename(file)[/\A\d+/].to_i }.max.to_i
    version = [ latest + 1, Time.now.utc.strftime("%Y%m%d%H%M%S").to_i ].max

    create_file "db/migrate/#{version}_create_idempotent_requests.rb", <<~RUBY
      class CreateIdempotentRequests < ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]
        def change
          create_table :idempotent_requests#{POSTGRESQL ? ", id: :uuid" : ""} do |t|
            t.string :key, null: false
            t.#{DB_PRIMARY_KEY} :user_id
            t.string :endpoint, null: false
            t.string :fingerprint, null: false
            t.integer :status, null: false
            t.json :body, null: false

            t.timestamps
          end

          # A concurrent retry loses the insert rather than racing the work.
          add_index :idempotent_requests, [ :user_id, :key, :endpoint ], unique: true
          add_index :idempotent_requests, :created_at
        end
      end
    RUBY
  end

  # The repository and its hooks come before the database, so that when db:create
  # aborts below the owner is left with a repo, hooks, and two commands to run
  # (`bin/rails db:prepare`, then `git add -A && git commit`) rather than a
  # directory with no history and four steps to find in this file.
  git :init
  install_git_hooks

  # Create and migrate database.
  #
  # abort_on_failure, because the default is worse than it looks: Thor's
  # rails_command swallows a non-zero exit, so a migration that aborts leaves the
  # app with no db/schema.rb and every later `bin/rails` refusing to run — and
  # generation still prints "template applied successfully" and commits. Better to
  # stop here, where the reason is on screen, than to hand over an app that says
  # it is fine.
  say "Setting up database...", :yellow
  rails_command "db:create", abort_on_failure: true
  rails_command "db:migrate", abort_on_failure: true

  # Arm the query ledger: whatever shapes the shipped suite emits are in
  # db/queries.yml before the first push, so the CI job has a file to check —
  # docs/rules/query-ledger.md. Not abort_on_failure: a suite that cannot run here
  # leaves the gate unarmed, which `bin/rails db:queries` fixes later.
  say "Recording the query ledger...", :yellow
  rails_command "db:queries"

  # The commit is the last thing generation does, and until now it could sink all
  # of it: a machine with no `user.email` — a fresh container, a CI runner — fails
  # with `empty ident name`, `rails new` exits non-zero, and everything that
  # succeeded looks like it did not. The repo and the staged tree are the parts
  # that matter; the commit is a convenience, so it is skipped with a note rather
  # than taken as fatal.
  git add: "."

  # `git :init` above ran here without a path, so this does too.
  identity = `git config user.email`.strip
  if identity.empty?
    say "Skipping the initial commit: git has no user.email on this machine.", :yellow
    say "Everything is staged — set one and `git commit` when you are ready.", :yellow
  else
    git commit: %Q{ -m "Initial commit from Rails Rocket Sheep template" }
  end

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

  if API
    say "  4. Name the client origins CORS will allow:"
    say "     bin/rails credentials:edit   # api: { allowed_origins: [...] }"
    say ""
    say "  5. After `rails g devise User`, move its route under the version prefix:"
    say "     config/routes.rb — the commented devise_for line shows how"
    say ""
    say "  6. Add your first endpoint: docs/sop/add-an-endpoint.md"
    say "     bin/rails api:contract       # generate openapi.yaml from the tests"
    say ""
    say "  7. Start developing:"
    say "     bin/rails server"
  else
    say "  4. Update SEO URLs:"
    say "     - public/robots.txt (Sitemap URL)"
    say "     - .github/workflows/lighthouse.yml (production URL)"
    say ""
    say "  5. Start developing:"
    say "     bin/dev"
  end

  say ""
  say "  Deploy when ready:"
  say "     kamal setup && kamal deploy"
  say ""
end
