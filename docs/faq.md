# FAQ

---

## Versions and compatibility

**Which Ruby and Rails versions?**
Ruby 3.2+ and Rails 8.0+. Developed and tested against Ruby 3.4.7 and Rails 8.0.

**Does it work with SQLite or MySQL?**
No. The template removes `sqlite3` and assumes PostgreSQL throughout — UUID primary keys via `gen_random_uuid()`, and a four-database Solid Stack configuration. Porting to MySQL means rewriting `config/database.yml` and choosing a different primary key strategy.

**Why PostgreSQL 13 specifically?**
`gen_random_uuid()` became a built-in in PostgreSQL 13. On earlier versions you'd need the `pgcrypto` extension enabled.

**Will it work when Rails 8.1 or 9 ships?**
The template writes plain Rails files, so there's no gem to become incompatible. What can break is the template's *generation* step — it patches specific files (`config/application.rb`, `config/environments/development.rb`, the layout) by matching on their content. If Rails changes those files, the injections may need updating. Apps already generated are unaffected.

---

## Using it

**Can I use it on an existing app?**
Not as a template — `rails new` only applies to new apps. You can copy individual pieces: `app/services/application_service.rb`, `app/lib/registry_base.rb`, the SEO helper and tests, and `CLAUDE.md` all drop into an existing app unchanged. The database, Kamal, and generator configuration do not.

**Can I generate more than one app with it?**
Yes. Clone it locally and point `--template` at the local path — it's faster than fetching over HTTP each time, and it lets you keep your own modifications.

**How do I customise the template itself?**
Fork it. Files under `templates/` are copied verbatim (or ERB-rendered for `.tt` files), and `template.rb` orchestrates. Adding a file means dropping it in `templates/` and adding a `copy_template_file` line.

**Why is the layout still ERB when everything else is Slim?**
Devise's views and several Rails generators assume an ERB layout. Keeping the layout in ERB avoids fighting them. Application views are Slim.

**Do I have to use Slim?**
No, but the template's home view and the generated `CLAUDE.md` assume it. Removing Slim means converting `app/views/home/index.html.slim` and editing the conventions doc.

---

## Things that surprise people

**Why does `rails g model` create UUID primary keys?**
The template configures `config.generators` with `primary_key_type: :uuid`. Consequence: foreign keys must be declared as `t.uuid :parent_id`, not `t.references`. Get this wrong and you'll see a type mismatch error when adding the foreign key.

**Why are there four databases in development?**
Solid Queue, Solid Cache, and Solid Cable each get their own, matching the production layout. It means job or cache tables never appear in your primary `schema.rb`, and you can move any of them to a separate host later by changing one environment variable.

**A snail appeared at the end of my test run. What is it?**
Slowpoke, reporting tests over 500ms. It prints nothing when the suite is clean. Raise the bar for one run with `SLOWPOKE_THRESHOLD=2.0 bin/test`, or change the project default in `test/support/slowpoke.rb`. Full guide in `docs/sop/find-slow-tests.md`.

**Why is `test/fixtures/*.yml` empty when I generate a model?**
Deliberate. The template overrides Rails' fixture generator via `lib/templates/test_unit/model/fixtures.yml`. The stock generator emits two placeholder records with identical values, which raises `PG::UniqueViolation` the moment a table has a unique index — Devise's `email` column being the usual first casualty. Add fixtures with values you actually chose.

**Why doesn't `Post.all` exclude soft-deleted records?**
Discard deliberately adds no default scope. Use `Post.kept`. Default scopes are hard to escape and cause more problems than they solve — but it does mean every query against a discardable model is a place to forget.

**Why does development use Solid Cable instead of `:async`?**
So WebSocket behaviour matches production. The `:async` adapter only works within a single process, which hides bugs that appear the moment you deploy.

**The Solid Stack config files are written twice. Why?**
Rails 8 runs its own `solid_cache:install solid_queue:install solid_cable:install` after bundling, which overwrites anything a template wrote earlier. The template therefore writes them in `after_bundle`, after those generators have run. Writing them earlier as well would make Rails' installers stop and prompt you to confirm an overwrite.

---

## Removing things

**Can I remove Devise / PaperTrail / Slim / SEO?**
Yes — everything is a plain file with no cross-dependencies, with one exception: `app/lib/app_config.rb` uses `RegistryBase`, so removing the registry module means rewriting or deleting `AppConfig` too. See [What's Included](whats-included.md#removing-things-you-dont-want).

**I don't want the `CLAUDE.md` conventions.**
Delete the file. Nothing reads it at runtime.

---

## AI agents

**Does this only work with Claude Code?**
No. `CLAUDE.md` is the single source, and three pointers route other tools to it:

- **Claude Code** — reads `CLAUDE.md` and `.claude/commands/`
- **Cursor** — reads `.cursor/rules/conventions.mdc` and `.cursor/commands/`, both shipped. The commands are the same files, mirrored at generation time rather than forked.
- **Anything else** — `AGENTS.md` carries an orientation table and a commands table. Cursor and a growing number of tools read `AGENTS.md` natively.

For a tool with no slash-command concept, the commands still work — they're markdown instruction files. Tell the agent to "follow `.claude/commands/pr_submit.md`".

**Do I still need to review what the agent writes?**
Yes. This reduces divergence between sessions — it doesn't replace review. An agent deep in a long debugging session will violate the conventions occasionally.

---

## Licensing

**What does the license permit?**
See [LICENSE](../LICENSE) — it is authoritative over anything summarised here. In short: a perpetual, one-time-purchase commercial license, in a Single Application or Unlimited Applications tier. You may build personal, commercial, and client work with it.

**What can't I do with it?**
Resell, republish, or otherwise distribute the template itself, share your repo access outside your organisation, or use it to build a competing template or starter-kit product. The restrictions apply to the template, not to what you build with it.

**Can I open-source an app I built with it?**
Yes, under any license you choose — provided it's a genuine application rather than, in substance, a republication of the template. Publishing a freshly generated, substantially unmodified app is redistribution and isn't permitted. See LICENSE §5.

**Can a contractor work on my app?**
Yes. Someone working only on your generated application isn't a "Developer" under the license and needs no license of their own. A contractor who takes a copy of the *template* away with them needs their own. See LICENSE §3.3.

**Is there a refund?**
Within 30 days, where you haven't put a generated app into production. See LICENSE §8.

**Do I owe anything on apps I build with it?**
No. Generated apps are yours. The template is applied once and leaves behind ordinary Rails files.

**Are there updates?**
The template is versioned and fixes are published, but there is no upgrade path *into* an already-generated app by design — once applied, the output is your code, not a dependency. Re-generating a fresh app picks up the current version.

---

## Support

**Something's broken in generation.**
Open an issue with your Ruby version, Rails version, PostgreSQL version, and the generator output. Generation problems are usually version-specific and worth fixing for everyone.

**Something's broken in my app.**
Once generated, it's a normal Rails app — normal Rails debugging applies. The generated `docs/` and `CLAUDE.md` cover the template-specific patterns.
