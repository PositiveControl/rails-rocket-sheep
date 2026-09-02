# frozen_string_literal: true

# Assert the envelope, not just the status — docs/rules/api-testing.md.
#
# A 422 with the wrong body shape passes a status assertion and breaks every
# client, so the shape is asserted in one line rather than by eye.
module ApiHelpers
  def assert_problem(type, status:, field: nil)
    assert_response status
    assert_equal "application/problem+json", response.media_type,
                 "an error response must be a problem document"

    body = JSON.parse(response.body)
    assert_equal "/problems/#{type}", body["type"], "problem type"
    assert_equal Rack::Utils.status_code(status), body["status"], "status in the body must match the status line"
    assert body["title"].present?, "a problem document needs a title"
    refute body.key?("success"), "the status line already says whether it succeeded"

    return if field.nil?

    fields = Array(body["errors"]).map { |e| e["field"] }
    assert_includes fields, field.to_s, "expected an errors entry for #{field}"
  end

  # A token for a scope, so the negative cases are as cheap to write as the
  # positive one — docs/rules/api-auth.md.
  #
  # Doorkeeper's migration makes `application_id` NOT NULL, so a token needs a
  # client. One per suite is enough; the tests care about the scope, not the app.
  def api_headers(user, scopes: "read write")
    token = Doorkeeper::AccessToken.create!(application: api_test_client,
                                            resource_owner_id: user.id,
                                            scopes: scopes)
    { "Authorization" => "Bearer #{token.token}" }
  end

  def api_test_client
    Doorkeeper::Application.find_or_create_by!(name: "test client") do |application|
      application.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
      application.scopes = "read write"
    end
  end
end

ActiveSupport::TestCase.include ApiHelpers
