# frozen_string_literal: true

# Every API controller inherits this. It owns the three things every endpoint
# shares: who is calling, what an error looks like, and how big a page may be.
#
#   class Api::V1::ItemsController < Api::V1::BaseController
#     before_action -> { doorkeeper_authorize! :read },  only: [ :index, :show ]
#     before_action -> { doorkeeper_authorize! :write }, only: [ :create ]
#   end
module Api
  module V1
    class BaseController < ActionController::API
      PER_PAGE_MAX = 100
      PER_PAGE_DEFAULT = 25

      # One boundary, so no action decides an error shape inside a rescue —
      # docs/rules/exception-boundary.md.
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionController::ParameterMissing, with: :malformed
      rescue_from Cursor::InvalidCursor, with: :malformed

      # Doorkeeper renders its own 401 and 403 by default, in its own shape, which
      # would be the second error format in an app whose whole point is having one.
      # `handle_auth_errors :raise` in the initializer sends them here instead.
      # TokenForbidden descends from InvalidToken, so it is declared second: a
      # later handler wins the lookup.
      rescue_from Doorkeeper::Errors::InvalidToken, with: :unauthenticated
      rescue_from Doorkeeper::Errors::TokenForbidden, with: :insufficient_scope

      private

      # docs/rules/api-auth.md — the token's resource owner, not a session.
      def current_user
        @current_user ||= doorkeeper_token && User.find_by(id: doorkeeper_token.resource_owner_id)
      end

      # RFC 9457 problem details. The only thing in this app that writes an error
      # body — docs/rules/error-envelope.md.
      #
      # `type` is the contract and a client branches on it; `detail` is prose for a
      # human and will be reworded. A relative URI reference is what RFC 9457
      # permits, which is why there is no hostname to configure.
      def problem(type:, title:, status:, detail: nil, **extensions)
        render content_type: "application/problem+json",
               status: status,
               json: {
                 type: "/problems/#{type}",
                 title: title,
                 status: Rack::Utils.status_code(status),
                 detail: detail,
                 **extensions
               }.compact
      end

      def invalid(contract_or_record)
        problem type: "validation-failed",
                title: "Validation failed",
                status: :unprocessable_content,
                errors: error_details_for(contract_or_record)
      end

      def not_found
        problem type: "not-found", title: "Not found", status: :not_found,
                detail: "No such resource, or not one you may see"
      end

      def unauthenticated
        problem type: "unauthenticated", title: "Not authenticated",
                status: :unauthorized, detail: "Present a valid bearer token"
      end

      def insufficient_scope
        problem type: "insufficient-scope", title: "Insufficient scope",
                status: :forbidden, detail: "This token's scopes do not cover this request"
      end

      def malformed(exception)
        problem type: "malformed-request", title: "Malformed request",
                status: :bad_request, detail: exception.message
      end

      # Arrives from the internet, so it is clamped — an unclamped per_page is an
      # unbounded query with extra steps.
      def per_page
        (params[:per_page].presence || PER_PAGE_DEFAULT).to_i.clamp(1, PER_PAGE_MAX)
      end

      def error_details_for(subject)
        return subject.error_details if subject.respond_to?(:error_details)

        subject.errors.map { |e| { field: e.attribute, code: e.type, detail: e.full_message } }
      end
    end
  end
end
