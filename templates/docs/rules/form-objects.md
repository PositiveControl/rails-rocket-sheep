---
id: form-objects
title: Form objects — ApplicationForm, never nested attributes
applies_to: ["app/forms/**/*.rb", "app/controllers/**/*.rb", "test/forms/**/*.rb"]
triggers: ["form object", "ApplicationForm", "accepts_nested_attributes_for", "nested attributes", "multi-model form", "signup form", "wizard", "non-column field", "accept_terms"]
see_also: ["service-objects", "turbo-status", "policy-objects"]
tokens: 680
---

# Form objects

The biggest gap in a plain Rails app: a form that writes two models, or none.
`accepts_nested_attributes_for` is the alternative and it is worse — it hides
writes inside a model's assignment path and makes error messages unspeakable
(`items.attributes.0.quantity`).

```ruby
# app/forms/application_form.rb
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
end
```

```ruby
# app/forms/signup_form.rb
class SignupForm < ApplicationForm
  attribute :email,        :string
  attribute :password,     :string
  attribute :company_name, :string
  attribute :accept_terms, :boolean, default: false

  validates :email, :password, :company_name, presence: true
  validates :accept_terms, acceptance: true

  attr_reader :user

  def save
    return false if invalid?

    ApplicationRecord.transaction do
      company = Company.create!(name: company_name)
      @user   = company.users.create!(email:, password:, role: :owner)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    promote_errors(e.record)
    false
  end
end
```

The controller treats it exactly like a model — that's the whole point:

```ruby
def create
  @form = SignupForm.new(signup_params)

  if @form.save
    sign_in @form.user
    redirect_to dashboard_path, notice: "Welcome"
  else
    render :new, status: :unprocessable_content   # see turbo-status
  end
end
```

A form object has no routes, so pass an explicit `url:`:

```slim
= form_with model: @form, url: signup_path do |f|
  = render ErrorSummaryComponent.new(record: @form)
  = f.email_field :email
  = f.text_field :company_name
```

## When

**Reach for one when:** one submit writes ≥2 models; the form has fields that
aren't columns (`accept_terms`, `confirm_email`); a wizard step needs partial
validation; or the same model needs different rules in two contexts.

**Don't when:** the form maps to one model. `form_with model: @order` is already
the right answer.

**Form vs service:** the form owns validation and the shape of user input; a
[service](service-objects.md) owns coordination. A form may call a service. A service
never knows a form exists.
