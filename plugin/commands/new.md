---
description: "Generate a Rails 8 app from the Rails Rocket Sheep template"
argument-hint: "<app-name> [--api] [--database=postgresql|mysql|trilogy|mariadb-mysql|mariadb-trilogy]"
---

# New Rails Rocket Sheep app

Generate a Rails 8 application from the Rails Rocket Sheep template, so the app
starts with a `CLAUDE.md`, one-convention-per-file rules, workflow commands, and
CI gates already in place. Arguments: `$ARGUMENTS`.

1. Parse the arguments. The first word is the app name and is required; stop and
   ask if it is missing. `--api` selects the JSON API mode. `--database=` defaults
   to `postgresql`; the template accepts `mysql`, `trilogy`, `mariadb-mysql`, and
   `mariadb-trilogy` and refuses anything else, so do not pass another value.
2. Preflight, and stop with the failing check named if any fails:
   `rails -v` reports 8.0 or newer, `git --version` succeeds, and the current
   directory is not inside a Rails app (`config/application.rb` does not exist
   here or in any parent). Generating inside an app nests one app in another.
3. Run the generator. It shallow-clones the template repo to a temp directory and
   takes several minutes with bundling; give it a long timeout and do not
   interrupt it. Do not add `--skip-bundle` unless the user asked for it.

   ```bash
   rails new <app-name> --database=<database> [--api] \
     --template=https://raw.githubusercontent.com/PositiveControl/rails-rocket-sheep/v1.0.1/template.rb
   ```

4. If it fails, show the last thirty lines of output and stop. Do not retry with
   different flags. Bundler failures are usually a missing database client
   library, and the error names it.
5. When it succeeds, report the path and the next commands, and nothing else. The
   generated app's own `CLAUDE.md` is the entry point for everything after this.

   ```bash
   cd <app-name>
   rails g devise User && bin/rails db:migrate
   bin/test
   bin/dev          # server-rendered app; bin/rails server for --api
   ```

   Then read `CLAUDE.md` in the new app before touching any file in it.
