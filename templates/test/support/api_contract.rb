# frozen_string_literal: true

# Records every request an integration test makes, so the OpenAPI document is a
# build output of the suite rather than a file someone maintains —
# docs/rules/openapi-contract.md.
#
# Inert unless OPENAPI_OUT is set, which only `rake api:contract` does. An
# untested endpoint records nothing, which is the property this buys: it cannot be
# documented without a test.
if ENV["OPENAPI_OUT"]
  module ApiContractRecorder
    # Path parameters are recognised by shape, not by route introspection: the
    # route set knows the pattern but not which request matched it here.
    ID_SEGMENT = /\A([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)\z/i

    def process(method, path, **kwargs)
      result = super
      ApiContractRecorder.record(method, path, response)
      result
    rescue StandardError
      raise
    end

    def self.record(method, path, response)
      route = URI.parse(path.to_s).path.split("/").map { |s| s.match?(ID_SEGMENT) ? "{id}" : s }.join("/")
      return unless route.start_with?("/api/")

      entry = {
        method: method.to_s.upcase,
        path: route,
        status: response.status,
        media_type: response.media_type,
        keys: top_level_keys(response),
        problem_type: problem_type(response)
      }
      File.open(ENV.fetch("OPENAPI_OUT"), "a") { |f| f.puts JSON.generate(entry) }
    end

    def self.top_level_keys(response)
      return [] unless response.media_type.to_s.include?("json")

      body = JSON.parse(response.body)
      body.is_a?(Hash) ? body.keys.sort : []
    rescue JSON::ParserError
      []
    end

    # Error shapes are as much the contract as success shapes, and they are the
    # half clients get wrong.
    def self.problem_type(response)
      return nil unless response.media_type == "application/problem+json"

      JSON.parse(response.body)["type"]
    rescue JSON::ParserError
      nil
    end
  end

  ActionDispatch::Integration::Session.prepend(ApiContractRecorder)
end
