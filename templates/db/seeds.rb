# frozen_string_literal: true

# Seeds — safe to run repeatedly. Everything here is idempotent.
#
#   bin/rails db:seed
#
# Creates a single admin user so a fresh checkout has something to log in as.
#
# The password comes from SEED_ADMIN_PASSWORD when set, otherwise a random one
# is generated and printed once. Nothing is hardcoded: a known default password
# that reaches production is the kind of thing that ends up in a breach report.

def seed_admin_user
  unless defined?(User)
    puts "No User model yet — run `rails g devise User` first, then `bin/rails db:seed`."
    return
  end

  email = ENV.fetch("SEED_ADMIN_EMAIL", "admin@example.com")

  if User.exists?(email: email)
    puts "Admin user #{email} already exists — leaving it alone."
    return
  end

  generated = ENV["SEED_ADMIN_PASSWORD"].blank?
  password = ENV.fetch("SEED_ADMIN_PASSWORD") { SecureRandom.alphanumeric(24) }

  user = User.new(email: email, password: password, password_confirmation: password)
  user.confirmed_at = Time.current if user.respond_to?(:confirmed_at=)

  # Petergate: grant the admin role if roles are configured on the model.
  user.roles = [ :admin ] if user.respond_to?(:roles=)

  unless user.save
    puts "Could not create admin user: #{user.errors.full_messages.to_sentence}"
    return
  end

  puts "Created admin user: #{email}"
  return unless generated

  puts "  Password: #{password}"
  puts "  This is shown once and is not stored anywhere. Save it now."
end

if Rails.env.production? && ENV["SEED_ALLOW_PRODUCTION"].blank?
  puts "Refusing to seed in production. Set SEED_ALLOW_PRODUCTION=1 if you really mean it."
else
  seed_admin_user
end
