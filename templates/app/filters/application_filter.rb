# frozen_string_literal: true

# Turns an untrusted query string into scope calls on a relation —
# docs/rules/filtering-sorting.md.
#
# The declarations are the allowlist, and they are data on purpose: nothing else
# can generate the documented query parameters from an `if params[:x]` branch.
#
#   class ItemFilter < ApplicationFilter
#     filter :status,      :string,  only: Item::STATUSES
#     filter :category_id, :string
#     filter :min_price,   :integer, scope: ->(relation, value) { relation.where(price_cents: value..) }
#
#     sortable :created_at, :price_cents
#     default_sort :created_at, :desc
#   end
#
#   scope = ItemFilter.new(current_user.items, params).apply
class ApplicationFilter
  Definition = Struct.new(:name, :type, :only, :scope, keyword_init: true)

  class << self
    def filter(name, type, only: nil, scope: nil)
      definitions[name.to_sym] = Definition.new(name: name.to_sym, type: type, only: only, scope: scope)
    end

    def sortable(*names)
      sortables.concat(names.map(&:to_sym))
    end

    def default_sort(field, direction = :desc)
      @default_sort = [ field.to_sym, direction.to_sym ]
    end

    def definitions = @definitions ||= inherited_from(:definitions, {})
    def sortables   = @sortables   ||= inherited_from(:sortables, [])

    def default_sort_key
      @default_sort || (superclass.respond_to?(:default_sort_key) ? superclass.default_sort_key : nil) ||
        [ :created_at, :desc ]
    end

    private

    def inherited_from(reader, empty)
      superclass.respond_to?(reader) ? superclass.public_send(reader).dup : empty
    end
  end

  def initialize(relation, params)
    @relation = relation
    @params = params
  end

  # A filter narrows. It receives a relation already scoped to the caller and can
  # only add conditions to it — docs/rules/policy-objects.md.
  def apply
    relation = self.class.definitions.each_value.reduce(@relation) do |scope, definition|
      value = cast(definition)
      next scope if value.nil?

      definition.scope ? definition.scope.call(scope, value) : scope.where(definition.name => value)
    end

    field, direction = sort_key
    relation.order(field => direction, :id => direction)
  end

  # The sort the cursor has to encode. Always ends in a unique tiebreak, because a
  # non-unique sort makes cursor pages skip and repeat rows with no error —
  # docs/rules/cursor-pagination.md.
  def sort_key
    requested = @params[:sort].to_s.delete_prefix("-").to_sym
    return self.class.default_sort_key unless self.class.sortables.include?(requested)

    [ requested, @params[:sort].to_s.start_with?("-") ? :desc : :asc ]
  end

  private

  def cast(definition)
    raw = @params[definition.name]
    return nil if raw.nil? || raw == ""

    value = ActiveModel::Type.lookup(definition.type).cast(raw)
    return nil if definition.only && !Array(definition.only).map(&:to_s).include?(value.to_s)

    value
  end
end
