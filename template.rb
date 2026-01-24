# frozen_string_literal: true

# Rails Rocket Sheep - Highly Opinionated Rails 8 Template
#
# Usage:
#   rails new myapp --database=postgresql --template=path/to/template.rb
#
# What this template does:
#   - Configures Rails 8 Solid Stack (Queue, Cache, Cable - all database-backed)
#   - Sets up Kamal 2 deployment with PostgreSQL accessory
#   - Adds Devise + Petergate for authentication and authorization
#   - Configures UUID primary keys for all models
#   - Adds ApplicationService base class with Result pattern
#   - Adds RegistryBase module for configuration patterns
#   - Includes generic Stimulus controllers (toggle, modal)
#   - Sets up VCR for HTTP testing
#   - Configures Bullet for N+1 detection
#   - Creates comprehensive CLAUDE.md for AI assistants

TEMPLATE_ROOT = __dir__

# =============================================================================
# Helper Methods
# =============================================================================

def source_paths
  [File.join(TEMPLATE_ROOT, "templates"), TEMPLATE_ROOT]
end

def template_file(source, destination = nil)
  destination ||= source.sub(/\.tt$/, "")
  template source, destination
end

def copy_template_file(source, destination = nil)
  destination ||= source
  copy_file source, destination
end

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
gem "pagy", "~> 9.0"

# Templates
gem "slim-rails"

# Email (optional - Resend API)
gem "resend", "~> 0.17"

# Development gems
gem_group :development do
  gem "letter_opener_web", "~> 3.0"
end

gem_group :development, :test do
  gem "pry"
  gem "pry-rails"
  gem "bullet"
end

gem_group :test do
  gem "vcr", "~> 6.0"
  gem "webmock", "~> 3.0"
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

# Configure generators for UUIDs
inject_into_file "config/application.rb", after: "class Application < Rails::Application\n" do
  <<~RUBY
    # Use UUIDs as primary keys by default
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    # Autoload app/lib for registries and game config
    config.autoload_paths << Rails.root.join("app/lib")

  RUBY
end

# =============================================================================
# Phase 3: Application Configuration
# =============================================================================

say "Configuring application...", :green

# ApplicationRecord with UUID and implicit ordering
remove_file "app/models/application_record.rb"
template_file "app/models/application_record.rb.tt"

# Solid Queue configuration
copy_template_file "config/queue.yml"

# Solid Cache configuration
copy_template_file "config/cache.yml"

# Solid Cable configuration
copy_template_file "config/cable.yml"

# Recurring jobs configuration
copy_template_file "config/recurring.yml"

# =============================================================================
# Phase 4: Development Environment
# =============================================================================

say "Configuring development environment...", :green

# Configure Bullet for N+1 detection
inject_into_file "config/environments/development.rb", before: /^end\s*$/ do
  <<~RUBY

  # Bullet N+1 query detection
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true
    Bullet.add_footer = true
  end
  RUBY
end

# Configure letter_opener_web for email preview
inject_into_file "config/environments/development.rb", before: /^end\s*$/ do
  <<~RUBY

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

# Docker entrypoint script
template_file "bin/docker-entrypoint.tt"
chmod "bin/docker-entrypoint", 0755

# macOS-friendly test script
copy_template_file "bin/test"
chmod "bin/test", 0755

# Kamal secrets directory
empty_directory ".kamal"
create_file ".kamal/secrets", <<~SECRETS
  # Kamal deployment secrets
  # Load from environment or use direnv/dotenv

  KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
  RAILS_MASTER_KEY=$(cat config/master.key 2>/dev/null || echo "")
  POSTGRES_PASSWORD=$POSTGRES_PASSWORD
  DATABASE_URL=$DATABASE_URL
  QUEUE_DATABASE_URL=$QUEUE_DATABASE_URL
  CABLE_DATABASE_URL=$CABLE_DATABASE_URL
  CACHE_DATABASE_URL=$CACHE_DATABASE_URL
SECRETS

# =============================================================================
# Phase 7: Service Objects & Patterns
# =============================================================================

say "Adding service object patterns...", :green

# ApplicationService base class
copy_template_file "app/services/application_service.rb"

# RegistryBase module
copy_template_file "app/lib/registry_base.rb"

# Example registry
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

# =============================================================================
# Phase 9: Testing Setup
# =============================================================================

say "Configuring testing...", :green

# VCR support
copy_template_file "test/support/vcr.rb"

# Update test_helper to require VCR
inject_into_file "test/test_helper.rb", before: /^class ActiveSupport::TestCase/ do
  <<~RUBY
  # VCR for HTTP request recording
  require_relative "support/vcr"

  RUBY
end

# =============================================================================
# Phase 10: Code Quality
# =============================================================================

say "Setting up code quality tools...", :green

# Rubocop configuration
copy_template_file ".rubocop.yml"

# =============================================================================
# Phase 11: Documentation
# =============================================================================

say "Creating documentation...", :green

# CLAUDE.md for AI assistants
template "CLAUDE.md", "CLAUDE.md"

# Documentation directory
empty_directory "docs"
empty_directory "docs/how-tos"
empty_directory "docs/synthesis"
empty_directory "docs/plans"

template_file "docs/models.md.tt"
copy_template_file "docs/design-patterns.md"
copy_template_file "docs/architecture.md"

# =============================================================================
# Phase 12: Routes Configuration
# =============================================================================

say "Configuring routes and home page...", :green

# Create HomeController
create_file "app/controllers/home_controller.rb", <<~RUBY
  class HomeController < ApplicationController
    def index
    end
  end
RUBY

# Create home view directory and view
empty_directory "app/views/home"
create_file "app/views/home/index.html.slim", <<~'SLIM'
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
        - if user_signed_in?
          .text-purple-200.mb-4
            | Welcome back!
          = link_to "Sign Out", destroy_user_session_path, data: { turbo_method: :delete }, class: "px-6 py-3 bg-white/10 text-white rounded-lg hover:bg-white/20 backdrop-blur border border-white/20 transition"
        - else
          = link_to "Sign In", new_user_session_path, class: "px-6 py-3 bg-white text-purple-900 font-semibold rounded-lg hover:bg-purple-100 transition"
          = link_to "Sign Up", new_user_registration_path, class: "px-6 py-3 bg-white/10 text-white rounded-lg hover:bg-white/20 backdrop-blur border border-white/20 transition"

      .mt-12.text-purple-400.text-sm
        | Ready to build something amazing
SLIM

# Replace routes file entirely
remove_file "config/routes.rb"
create_file "config/routes.rb", <<~RUBY
  Rails.application.routes.draw do
    # Health check endpoint for Kamal
    get "up" => "rails/health#show", as: :rails_health_check

    # Email preview in development
    if Rails.env.development?
      mount LetterOpenerWeb::Engine, at: "/letter_opener"
    end

    # Root path
    root "home#index"
  end
RUBY

# =============================================================================
# Phase 13: Git Configuration
# =============================================================================

say "Configuring git...", :green

# Add to .gitignore
append_to_file ".gitignore", <<~GITIGNORE

  # Kamal secrets
  .kamal/secrets

  # Environment files
  .env*
  !.env.example

  # Claude Code settings
  .claude/

  # IDE
  .idea/
  .vscode/
GITIGNORE

# =============================================================================
# After Bundle
# =============================================================================

after_bundle do
  say "Running post-bundle setup...", :green

  # Note: PostgreSQL 13+ has gen_random_uuid() built-in, no pgcrypto needed

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
  say "  4. Start developing:"
  say "     bin/dev"
  say ""
  say "  5. Deploy when ready:"
  say "     kamal setup && kamal deploy"
  say ""
end
