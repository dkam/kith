class Post < ApplicationRecord
  # The cap is on the markup rather than on what was typed, because the markup
  # is what has to be stored, sanitised and — one day — sent somewhere else.
  BODY_LIMIT = 200_000
  TITLE_LIMIT = 200
  PHOTO_LIMIT = 20

  # Fixed at write time and never changed: see audience_is_immutable. Circles
  # will be added here, which is why the enum is integer-backed and sparse.
  enum :audience, { followers: 0, public: 10 }, prefix: true, validate: true

  belongs_to :actor

  # The body is HTML, written in the editor. It carries the post's photographs
  # inside it, as Action Text embeds, so a photo sits where its author put it
  # rather than in a tray underneath.
  has_rich_text :body, store_if_blank: false

  has_many :comments, -> { chronological }, dependent: :destroy
  has_many :feed_items, dependent: :delete_all
  has_many :notifications, as: :subject, dependent: :delete_all

  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
  scope :by, ->(actors) { where(actor: actors) }
  scope :publicly_visible, -> { where(audience: :public) }
  scope :readable, -> { with_rich_text_body_and_embeds.includes(:actor) }

  after_create_commit :fan_out

  before_validation :set_published_at, on: :create
  before_save :forget_attachment_urls

  validates :title, length: { maximum: TITLE_LIMIT }
  validates :published_at, presence: true
  validate :body_is_not_enormous
  validate :must_say_something
  validate :photo_count_is_sane
  validate :audience_is_immutable, on: :update

  delegate :display_name, :handle, to: :actor, prefix: false

  def local? = !remote?

  # The photographs embedded in the body, as Active Storage attachments —
  # which is what MediaController serves and what Visibility checks.
  def photos
    body.embeds_attachments
  end

  def photo_count = photo_blobs.size

  # A one-line summary for a page title, a feed heading or a notification.
  # Never the markup, and never a filename: a post that is only photographs
  # says so in words.
  def excerpt(length: 160)
    title.presence || plain_body.truncate(length).presence || photo_summary
  end

  # Whether the post is readable by someone with no account at all. Only public
  # posts will ever leave this instance.
  def leaves_the_instance? = audience_public?

  private
    def fan_out
      FanOutJob.perform_later(self)
    end

    def set_published_at
      self.published_at ||= Time.current
    end

    # Lexxy sends each embedded photo with the Active Storage blob URL it drew
    # the preview from. That URL is a bearer token: it works for anyone holding
    # it, for as long as the file exists, and it answers no question about who
    # is asking. Photos are served by MediaController, which re-checks the
    # post's audience on every request, so the URL is dropped before the body is
    # stored — and put back, by MediaHelper, only when the author opens the
    # editor again.
    #
    # It runs before_save rather than before_validation so that a post which
    # fails to save re-renders the editor with the photos still showing.
    def forget_attachment_urls
      return unless body.body

      stripped = body.body.fragment.replace(ActionText::Attachment.tag_name) do |node|
        node.tap { |attachment| attachment.remove_attribute("url") }
      end.to_html

      self.body = stripped unless stripped == body.body.to_html
    end

    # to_plain_text renders an embedded photo as "[beach.jpg]", which is a
    # filename rather than a sentence. Take the photos out before flattening.
    def plain_body
      return "" unless body.body

      body.body.fragment
        .update { |source| source.css(ActionText::Attachment.tag_name).each(&:remove) }
        .to_plain_text.squish
    end

    def photo_blobs
      body.body&.attachables&.grep(ActiveStorage::Blob) || []
    end

    def photo_summary
      case photo_count
      when 0 then ""
      when 1 then "A photo"
      else "#{photo_count} photos"
      end
    end

    def must_say_something
      return if title.present? || body.present?

      errors.add(:base, "A post needs a title, something to say, or a photo.")
    end

    def body_is_not_enormous
      errors.add(:base, "That post is too long to store.") if body.body&.to_html.to_s.length > BODY_LIMIT
    end

    def photo_count_is_sane
      errors.add(:base, "A post holds up to #{PHOTO_LIMIT} photos.") if photo_count > PHOTO_LIMIT
    end

    # The audience is a promise made to the reader at the moment of writing. A
    # post that was shown to followers must not silently become public, and a
    # public post must not silently retract.
    def audience_is_immutable
      errors.add(:audience, "can't be changed after a post is written") if audience_changed?
    end
end
