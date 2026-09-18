# The credential behind a member's MCP endpoint: the thing an agent holds
# instead of a session cookie.
#
# It is a bearer token, and it is shown in full on the settings page whenever
# the member asks — so it is stored as written rather than digested. That is
# the same bargain as the invite code, and the same bargain as the session id
# in the cookie: the value only ever leaves here to the person it belongs to.
#
# It grants no more than the member can already see. Every tool behind the
# endpoint reads through Visibility, and #access says so in the schema so that
# a token which may one day write is a different value rather than a different
# code path.
class McpToken < ApplicationRecord
  # base58 again, and longer than an invite code because nobody types this one
  # and it does not expire: ~140 bits.
  TOKEN_LENGTH = 24

  # Circles, writing and posting all come later. Leave room.
  enum :access, { read_only: 0 }, prefix: true, validate: true

  belongs_to :member

  delegate :actor, to: :member

  before_validation :set_token, on: :create

  validates :token, presence: true, uniqueness: true
  validates :name, length: { maximum: 80 }

  # The endpoint is answered by whoever presents the token, so the lookup is
  # the whole of authentication. nil rather than an exception: the controller
  # turns "no such token" into the same 404 as everything else the caller may
  # not see.
  def self.authenticate(token)
    return nil if token.blank?

    find_by(token: token)
  end

  # What the tools behind the endpoint are allowed to see. Constructed from the
  # member's actor, exactly as a signed-in request would be — there is no
  # second privacy model for agents.
  def visibility
    @visibility ||= Visibility.new(actor)
  end

  # Rotating is a delete and a create in one: the old value never comes back,
  # and anything still holding it starts getting 404s.
  def rotate!
    update!(token: self.class.generate_token, last_used_at: nil)
  end

  def touch_last_used
    update_column(:last_used_at, Time.current)
  end

  def self.generate_token
    loop do
      candidate = SecureRandom.base58(TOKEN_LENGTH)
      break candidate unless exists?(token: candidate)
    end
  end

  private
    def set_token
      self.token ||= self.class.generate_token
    end
end
