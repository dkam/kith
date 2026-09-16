module NotificationsHelper
  # The sentence a notification is. Names are rendered through
  # shared/_actor_name elsewhere; here we only supply the predicate.
  def notification_sentence(notification)
    case notification.kind
    when "new_follower" then "asked to follow you."
    when "follow_accepted" then "accepted your follow."
    when "new_comment" then "replied to #{notification.subject.post.excerpt(length: 60).inspect.delete('"')}."
    end
  end
end
