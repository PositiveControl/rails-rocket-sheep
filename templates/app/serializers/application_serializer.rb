# frozen_string_literal: true

# One serializer per resource, one shape per resource — docs/rules/serialization.md.
#
# A subclass implements #fields, and may declare `optional` fields (omitted unless
# the client asks for them) and `includable` associations (each naming the preload
# it needs). Nothing else in the app builds a response body.
#
#   class ItemSerializer < ApplicationSerializer
#     optional :description
#     includable :category, preload: :category
#
#     def fields
#       { id: record.id, status: record.status, title: record.title }
#     end
#
#     def category = { id: record.category.id, name: record.category.name }
#   end
class ApplicationSerializer
  # A response a client cannot correlate is not a smaller response, it is a
  # broken one — docs/rules/sparse-fieldsets-includes.md.
  ALWAYS = %i[id].freeze

  class << self
    def optional(*names)
      optional_fields.concat(names.map(&:to_sym))
    end

    def includable(name, preload:)
      includables[name.to_sym] = preload
    end

    def optional_fields
      @optional_fields ||= inherited_from(:optional_fields, [])
    end

    def includables
      @includables ||= inherited_from(:includables, {})
    end

    # Applies the preloads a request's `include` list needs, to the relation,
    # before it is paginated — docs/rules/n-plus-one.md.
    #
    # The guard lives here because `relation.preload(*[])` raises, and a caller
    # writing that splat by hand gets an endpoint that works with `?include=` and
    # blows up without it.
    def preload(relation, include: nil)
      names = preloads_for(include)
      names.any? ? relation.preload(*names) : relation
    end

    def preloads_for(include)
      includables.values_at(*parse_includes(include)).compact
    end

    def one(record, fields: nil, include: nil)
      { data: new(record, fields: fields, include: include).as_json }
    end

    def collection(records, fields: nil, include: nil, **meta)
      rows = records.map { |record| new(record, fields: fields, include: include).as_json }
      { data: rows }.merge(meta)
    end

    # Unknown names are ignored rather than rejected: a newer client asking for a
    # field this build does not have should get the resource, not a 422.
    def parse_includes(list)
      list.to_s.split(",").map { |name| name.strip.to_sym } & includables.keys
    end

    private

    def inherited_from(reader, empty)
      superclass.respond_to?(reader) ? superclass.public_send(reader).dup : empty
    end
  end

  attr_reader :record

  def initialize(record, fields: nil, include: nil)
    @record = record
    @requested = fields.to_s.split(",").map { |name| name.strip.to_sym }
    @includes = self.class.parse_includes(include)
  end

  def fields
    raise NotImplementedError, "#{self.class} must implement #fields"
  end

  def as_json(*)
    body = fields
    requested_optionals.each { |name| body[name] = optional_value(name) }
    body = body.slice(*(@requested | ALWAYS)) if @requested.any?
    @includes.each { |name| body[name] = public_send(name) }
    body
  end

  # Minor units with a currency, never a float — docs/rules/serialization.md.
  def money(cents, currency: "USD")
    { amount_cents: cents.to_i, currency: currency }
  end

  # ISO 8601, never a bare epoch integer.
  def iso(time)
    time&.iso8601
  end

  private

  # An optional field is absent unless asked for by name, and #fields does not
  # carry it. Declaring it optional is the whole declaration: the value comes from
  # a method of that name if the serializer defines one, and from the record
  # otherwise. Requiring #fields to list it too meant forgetting one of the two
  # produced a silent nil.
  def requested_optionals
    self.class.optional_fields & @requested
  end

  def optional_value(name)
    respond_to?(name) ? public_send(name) : record.public_send(name)
  end
end
