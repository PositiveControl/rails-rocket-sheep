# frozen_string_literal: true

# A client that times out does not know whether the write happened, so it retries.
# On a write with an external side effect the retry must replay rather than repeat —
# docs/rules/idempotency.md.
#
# Rows live in a table, not the cache: the guarantee has to survive an eviction and
# a deploy. The unique index on (user_id, key) is what makes a concurrent retry lose
# the insert rather than race the work.
class IdempotentRequest < ApplicationRecord
  WINDOW = 24.hours

  validates :key, :fingerprint, :endpoint, presence: true

  class KeyReused < StandardError; end

  class << self
    # The stored response, or nil on the first call. Raises when the same key
    # arrives with different content, because that is a broken key generator and
    # replaying the old response would hide it.
    def replay(key:, user:, endpoint:, fingerprint:)
      record = active.find_by(key: key, user_id: user&.id, endpoint: endpoint)
      return nil if record.nil?
      raise KeyReused, "Idempotency-Key was used for a different request" if record.fingerprint != digest(fingerprint)

      record
    end

    def record!(key:, user:, endpoint:, fingerprint:, status:, body:)
      create!(key: key, user_id: user&.id, endpoint: endpoint,
              fingerprint: digest(fingerprint), status: status, body: body)
    end

    def active
      where(created_at: WINDOW.ago..)
    end

    def digest(payload)
      Digest::SHA256.hexdigest(payload.to_s)
    end
  end
end
