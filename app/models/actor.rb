# Anything that can author a post or be followed: a member of this instance, a
# person on another Kith or ActivityPub server, or a syndication feed.
#
# Subclasses are LocalActor, RemoteActor and FeedActor. Nothing but LocalActor
# exists in phase 1, but the seam is here so federation does not require a
# migration of every foreign key in the app.
class Actor < ApplicationRecord
  HANDLE_FORMAT = /\A[a-z0-9_]{2,32}\z/

  enum :discoverable, { everyone: 0, connections_only: 1, invisible: 2 }, validate: true

  has_one :member, dependent: :destroy
  has_one_attached :avatar

  normalizes :handle, with: ->(handle) { handle.to_s.strip.downcase.delete_prefix("@") }
  normalizes :domain, with: ->(domain) { domain.presence&.strip&.downcase }

  validates :handle, presence: true, format: { with: HANDLE_FORMAT, message: "may only contain lowercase letters, numbers and underscores" }
  validates :handle, uniqueness: { scope: :domain, case_sensitive: false }
  validates :display_name, length: { maximum: 80 }

  scope :local, -> { where(domain: nil) }

  def local? = domain.nil?
  def remote? = !local?

  # "alice" locally, "alice@example.social" for anyone else.
  def full_handle = local? ? handle : "#{handle}@#{domain}"

  def to_s = display_name.presence || "@#{handle}"

  def to_param = handle
end
