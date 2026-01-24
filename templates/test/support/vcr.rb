# frozen_string_literal: true

require "vcr"
require "webmock/minitest"

VCR.configure do |config|
  # Store cassettes in test/vcr_cassettes
  config.cassette_library_dir = "test/vcr_cassettes"

  # Use WebMock for HTTP stubbing
  config.hook_into :webmock

  # Filter sensitive data from recordings
  # Add your API keys and secrets here
  config.filter_sensitive_data("<API_KEY>") { ENV["API_KEY"] }
  config.filter_sensitive_data("<RESEND_API_KEY>") { Rails.application.credentials.dig(:resend, :api_key) }

  # Record mode options:
  # :once - Record once, replay thereafter (default, recommended for CI)
  # :new_episodes - Record new requests, replay existing
  # :none - Only replay, never record (for CI)
  # :all - Always record (useful for debugging)
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }

  # Allow real HTTP connections for localhost (for system tests)
  config.ignore_localhost = true

  # Allow real connections to specific hosts if needed
  # config.ignore_hosts 'example.com'
end

# Helper method for using VCR in tests
#
# Usage in tests:
#   def test_external_api_call
#     vcr_cassette("external_api/get_users") do
#       result = ExternalApi.get_users
#       assert result.success?
#     end
#   end
#
module VcrTestHelper
  def vcr_cassette(name, options = {}, &block)
    VCR.use_cassette(name, options, &block)
  end
end

# Include helper in all test cases
class ActiveSupport::TestCase
  include VcrTestHelper
end
