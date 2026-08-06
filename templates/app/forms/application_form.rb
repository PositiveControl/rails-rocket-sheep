# frozen_string_literal: true

# Base class for form objects.
#
# A form object owns validation and the shape of user input. Reach for one when:
#
#   - one submit writes to two or more models
#   - the form has fields that aren't columns (accept_terms, confirm_email)
#   - a wizard step needs partial validation
#   - the same model needs different rules in two contexts (admin vs. self-serve)
#
# Don't when the form maps to a single model — `form_with model: @order` already
# handles that, and a form object around it is pure ceremony.
#
# Usage:
#
#   class SignupForm < ApplicationForm
#     attribute :email,        :string
#     attribute :password,     :string
#     attribute :company_name, :string
#     attribute :accept_terms, :boolean, default: false
#
#     validates :email, :password, :company_name, presence: true
#     validates :accept_terms, acceptance: true
#
#     attr_reader :user
#
#     def save
#       return false if invalid?
#
#       ApplicationRecord.transaction do
#         company = Company.create!(name: company_name)
#         @user   = company.users.create!(email:, password:, role: :owner)
#       end
#       true
#     rescue ActiveRecord::RecordInvalid => e
#       promote_errors(e.record)
#       false
#     end
#   end
#
# The controller treats it exactly like a model — that is the point:
#
#   def create
#     @form = SignupForm.new(signup_params)
#
#     if @form.save
#       redirect_to dashboard_path, notice: "Welcome"
#     else
#       render :new, status: :unprocessable_content
#     end
#   end
#
# In the view, pass an explicit url since a form object has no routes:
#
#   = form_with model: @form, url: signup_path do |f|
#     = render ErrorSummaryComponent.new(record: @form)
#
# A form object may call a service. A service must never know a form exists.
#
# See docs/rules/form-objects.md for where this sits relative to services.
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Form objects are never persisted; this keeps form_with from emitting a
  # PATCH for an object that has no id.
  def persisted?
    false
  end

  # Override in subclasses. Return true on success, false on failure with
  # errors populated.
  def save
    raise NotImplementedError, "#{self.class}#save must be implemented"
  end

  # Same contract as ActiveRecord: raise instead of returning false.
  def save!
    save || raise(ActiveModel::ValidationError, self)
  end

  private

  # Copy a failed record's errors onto the form so the error summary can render
  # them. Prefixes nothing — map keys yourself when the form's field names differ
  # from the record's.
  #
  # @param record [ActiveModel::Validations]
  def promote_errors(record)
    errors.merge!(record)
  end
end
