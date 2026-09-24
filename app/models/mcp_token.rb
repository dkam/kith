# The credential behind one of a member's MCP endpoints: the thing an agent
# holds instead of a session cookie.
#
# It is a bearer token, and it is shown in full on the settings page whenever
# the member asks — so it is stored as written rather than digested. That is
# the same bargain as the invite code, and the same bargain as the session id
# in the cookie: the value only ever leaves here to the person it belongs to.
#
# A member may hold several, named, because a reader on the phone and something
# that writes on the desktop are not the same grant. What each one may do is
# #access, and it is fixed at issue: a token that is handed out as read-only
# never quietly becomes able to write, for the same reason a post's audience
# never changes after it is written.
class McpToken < ApplicationRecord
  # base58 again, and longer than an invite code because nobody types this one
  # and it does not expire: ~140 bits.
  TOKEN_LENGTH = 24
  NAME_LIMIT = 80

  # Integer-backed and sparse, like posts.audience. Narrower grants — read a
  # single actor, write comments but not posts — go between these.
  enum :access, { read_only: 0, read_write: 10 }, prefix: true, validate: true

  ACCESS_LABELS = { "read_only" => "read only", "read_write" => "read and write" }.freeze

  belongs_to :member

  delegate :actor, to: :member

  scope :oldest_first, -> { order(created_at: :asc, id: :asc) }

  before_validation :set_token, on: :create

  validates :token, presence: true, uniqueness: true
  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validate :access_is_immutable, on: :update

  # The endpoint is answered by whoever presents the token, so the lookup is
  # the whole of authentication. nil rather than an exception: the controller
  # turns "no such token" into the same 404 as everything else the caller may
  # not see.
  def self.authenticate(token)
    return nil if token.blank?

    find_by(token: token)
  end

  def self.generate_token
    loop do
      candidate = SecureRandom.base58(TOKEN_LENGTH)
      break candidate unless exists?(token: candidate)
    end
  end

  # What the tools behind the endpoint are allowed to see. Constructed from the
  # member's actor, exactly as a signed-in request would be — there is no
  # second privacy model for agents.
  def visibility
    @visibility ||= Visibility.new(actor)
  end

  def writes? = access_read_write?

  # Sentence case, as everything else a member reads is.
  def access_label = ACCESS_LABELS.fetch(access)

  # Rotating is a delete and a create in one: the old value never comes back,
  # and anything still holding it starts getting 404s.
  def rotate!
    update!(token: self.class.generate_token, last_used_at: nil)
  end

  def touch_last_used
    update_column(:last_used_at, Time.current)
  end

  private
    def set_token
      self.token ||= self.class.generate_token
    end

    # Changing what a token may do would change it under whoever is holding it.
    # Revoke it and issue another instead.
    def access_is_immutable
      errors.add(:access, "can't be changed after an endpoint is made") if access_changed?
    end
end
