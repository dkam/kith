class Post < ApplicationRecord
  include AttachableMedia

  BODY_LIMIT = 40_000
  TITLE_LIMIT = 200
  PHOTO_LIMIT = 20

  # Fixed at write time and never changed: see audience_is_immutable. Circles
  # will be added here, which is why the enum is integer-backed and sparse.
  enum :audience, { followers: 0, public: 10 }, prefix: true, validate: true

  belongs_to :actor

  has_many :comments, -> { chronological }, dependent: :destroy
  has_many :feed_items, dependent: :delete_all

  has_many_attached :photos

  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
  scope :by, ->(actors) { where(actor: actors) }
  scope :publicly_visible, -> { where(audience: :public) }

  after_create_commit :fan_out

  before_validation :set_published_at, on: :create
  before_validation :render_body

  validates :body, length: { maximum: BODY_LIMIT }
  validates :title, length: { maximum: TITLE_LIMIT }
  validates :published_at, presence: true
  validate :must_say_something
  validate :photo_count_is_sane
  validate :audience_is_immutable, on: :update

  delegate :display_name, :handle, to: :actor, prefix: false

  def local? = !remote?

  # Safe to render unescaped because body_html is only ever written by
  # render_body, below, which puts it through Markdown.render's allowlist
  # sanitiser. The assertion lives here, next to the guarantee, rather than as
  # a .html_safe scattered across templates.
  def rendered_body
    body_html.to_s.html_safe
  end

  def excerpt(length: 160)
    title.presence || Markdown.excerpt(body, length: length)
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

    def render_body
      self.body_html = Markdown.render(body) if body_changed? || body_html.blank?
    end

    def must_say_something
      return if body.present? || title.present? || photos.attached?

      errors.add(:base, "A post needs a title, something to say, or a photo.")
    end

    def photo_count_is_sane
      errors.add(:photos, "are limited to #{PHOTO_LIMIT} per post") if photos.attachments.size > PHOTO_LIMIT
    end

    # The audience is a promise made to the reader at the moment of writing. A
    # post that was shown to followers must not silently become public, and a
    # public post must not silently retract.
    def audience_is_immutable
      errors.add(:audience, "can't be changed after a post is written") if audience_changed?
    end
end
