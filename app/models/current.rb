class Current < ActiveSupport::CurrentAttributes
  attribute :session

  delegate :member, to: :session, allow_nil: true

  def actor = member&.actor
end
