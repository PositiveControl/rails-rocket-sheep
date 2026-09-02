# frozen_string_literal: true

# Base class for service objects with consistent Result pattern.
#
# Usage:
#   class CreateUserService < ApplicationService
#     def initialize(params)
#       @params = params
#     end
#
#     def call
#       user = User.new(@params)
#       if user.save
#         success(user)
#       else
#         failure(user.errors.full_messages)
#       end
#     end
#   end
#
#   # Call the service
#   result = CreateUserService.call(name: "John", email: "john@example.com")
#
#   if result.success?
#     redirect_to result.value, notice: "User created!"
#   else
#     flash.now[:alert] = result.errors.join(", ")
#     render :new
#   end
#
# Error handling:
#   class TransferFundsService < ApplicationService
#     class InsufficientFundsError < StandardError; end
#
#     def call
#       raise InsufficientFundsError if @from_account.balance < @amount
#       # ...
#     end
#   end
#
#   # In controller:
#   begin
#     result = TransferFundsService.call(...)
#   rescue TransferFundsService::InsufficientFundsError => e
#     redirect_to account_path, alert: "Insufficient funds"
#   end
#
class ApplicationService
  # Result object for consistent return values.
  #
  # Three states, not two. A write can be correct, permitted, and still not safe to
  # complete without the client confirming something that changed underneath it — a
  # cart whose prices moved between loading and checkout is the ordinary example,
  # not an edge case. Forcing that into `failure` tells the caller to fix its input
  # when there is nothing wrong with its input. See docs/rules/status-codes.md,
  # which maps it to 409 with its own problem type.
  Result = Struct.new(:success, :value, :errors, :confirm, keyword_init: true) do
    # @return [Boolean] true if the operation succeeded
    def success?
      success
    end

    # @return [Boolean] true if the operation failed outright. False for a result
    # awaiting confirmation, which is neither.
    def failure?
      !success && confirm.nil?
    end

    # @return [Boolean] true if the caller has to confirm something and retry
    def needs_confirmation?
      !confirm.nil?
    end

    # Alias for value - useful when result represents a created record
    alias_method :record, :value
  end

  # Class-level call for convenient invocation
  # @return [Result] the result of calling the service
  def self.call(...)
    new(...).call
  end

  # Override in subclasses to implement the service logic
  # @return [Result] call success() or failure() to return a result
  def call
    raise NotImplementedError, "#{self.class}#call must be implemented"
  end

  private

  # Return a successful result
  # @param value [Object, nil] the value to return (optional)
  # @return [Result] a successful result
  def success(value = nil)
    Result.new(success: true, value: value, errors: [])
  end

  # Return a failed result
  # @param errors [String, Array<String>] the error message(s)
  # @return [Result] a failed result
  def failure(errors)
    errors = [ errors ] unless errors.is_a?(Array)
    Result.new(success: false, value: nil, errors: errors)
  end

  # Return a result the caller has to confirm before it can proceed.
  # @param details [Hash] what changed, in enough detail for the client to show it
  # @return [Result] a result that is neither a success nor a failure
  def needs_confirmation(**details)
    Result.new(success: false, value: nil, errors: [], confirm: details)
  end

  # Log an error (override for custom logging)
  # @param message [String] the error message
  # @param context [Hash] additional context
  def log_error(message, context = {})
    Rails.logger.error("[#{self.class.name}] #{message}", context)
  end

  # Log info (override for custom logging)
  # @param message [String] the info message
  # @param context [Hash] additional context
  def log_info(message, context = {})
    Rails.logger.info("[#{self.class.name}] #{message}", context)
  end
end
