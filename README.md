# Rails Rocket Sheep 🚀🐑

A highly opinionated, LLM-friendly, Rails 8 application template with the Solid Stack.

## What's Included

- **Rails 8 Solid Stack** - Database-backed Queue, Cache, and Cable (no Redis!)
- **Kamal 2 Deployment** - Docker-native deployment with PostgreSQL
- **Authentication** - Devise + Petergate for auth and roles
- **Soft Deletes** - Discard gem pre-configured
- **Audit Trail** - PaperTrail for versioning
- **UUID Primary Keys** - Secure, distributed-friendly IDs
- **Service Objects** - ApplicationService base class with Result pattern
- **Registry Pattern** - RegistryBase for configuration entities
- **Slim Templates** - Clean, readable views
- **Tailwind CSS** - Utility-first styling
- **Stimulus Controllers** - Generic toggle and modal controllers
- **VCR Testing** - HTTP request recording for tests
- **Bullet** - N+1 query detection
- **RuboCop** - Rails Omakase linting
- **Brakeman** - Security static analysis
- **CLAUDE.md** - AI assistant conventions

## Usage

### Create a New App

Fork this repo to your GitHub account and replace `YOUR_USERNAME` below, or use my username.

```bash
rails new myapp \
  --database=postgresql \
  --template=https://raw.githubusercontent.com/YOUR_USERNAME/rails-rocket-sheep/main/template.rb
```

Or clone and use locally:

```bash
git clone https://github.com/YOUR_USERNAME/rails-rocket-sheep.git
rails new myapp --database=postgresql --template=rails-rocket-sheep/template.rb
```

### After Creation

```bash
cd myapp

# Create your User model
rails g devise User

# Start development
bin/dev
```

### Deploy

1. Edit `config/deploy.yml` with your server details
2. Set up secrets in `.kamal/secrets`
3. Deploy:

```bash
kamal setup   # First time only
kamal deploy  # Deploy updates
```

## What the Template Does

1. **Configures Gems** - Adds Solid Stack, Devise, Petergate, Discard, PaperTrail, Pagy, Slim, VCR, Bullet, RuboCop, Brakeman
2. **Sets Up Multi-Database** - Separate databases for queue, cable, cache
3. **Configures UUIDs** - All models use UUID primary keys
4. **Creates Base Classes** - ApplicationService, RegistryBase, AppConfig
5. **Adds Stimulus Controllers** - toggle_controller.js, modal_controller.js
6. **Sets Up Deployment** - Dockerfile, docker-entrypoint, Kamal config
7. **Creates Documentation** - CLAUDE.md, docs/models.md, docs/design-patterns.md, docs/architecture.md
8. **Configures Development** - Bullet for N+1 detection, letter_opener for emails

## Customization

### Interactive Prompts

The template will ask for:
- Deploy host (server IP/hostname)
- Docker registry username

### Post-Creation

After running the template, you may want to:

1. **Customize CLAUDE.md** - Add project-specific conventions
2. **Update deploy.yml** - Configure your actual server and registry
3. **Add environment variables** - Set up `.kamal/secrets`
4. **Create models** - Start with `rails g devise User`

## Project Structure

```
myapp/
├── app/
│   ├── lib/                    # Registries and config (AppConfig, etc.)
│   ├── services/               # Service objects (inherit ApplicationService)
│   ├── models/                 # ActiveRecord models
│   ├── controllers/            # RESTful controllers
│   ├── views/                  # Slim templates
│   └── javascript/controllers/ # Stimulus controllers
├── config/
│   ├── deploy.yml              # Kamal deployment config
│   ├── database.yml            # Multi-database config
│   ├── queue.yml               # Solid Queue config
│   ├── cable.yml               # Solid Cable config
│   └── cache.yml               # Solid Cache config
├── docs/
│   ├── models.md               # Model documentation
│   ├── design-patterns.md      # UI/UX patterns + Slim/Tailwind gotchas
│   ├── architecture.md         # Architecture Decision Records
│   └── how-tos/                # Step-by-step guides
├── bin/
│   ├── docker-entrypoint       # Production DB setup script
│   └── test                    # macOS-friendly test runner
├── CLAUDE.md                   # AI assistant conventions
└── Dockerfile                  # Production Docker image
```

## Requirements

- Ruby 3.4+
- Rails 8.0+
- PostgreSQL 14+

## License

MIT
