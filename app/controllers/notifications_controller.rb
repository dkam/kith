class NotificationsController < ApplicationController
  PAGE_SIZE = 50

  def index
    # Every notification passes the same Visibility check as the feed. A
    # notification about something you may no longer see is a disclosure, so it
    # is dropped rather than shown as a ghost.
    @notifications = current_member.notifications
      .includes(:actor, :subject)
      .newest_first
      .limit(PAGE_SIZE)
      .select { |notification| visibility.notification?(notification) }
  end

  def update
    notification = current_member.notifications.find(params[:id])
    notification.read!

    redirect_to notification_target(notification)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def read_all
    current_member.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)

    # See FeedItemsController#read_all: refreshing the screen the app is on,
    # rather than pushing another copy of it.
    refresh_or_redirect_to notifications_path, notice: "All marked as read."
  end

  private
    def notification_target(notification)
      case notification.subject
      when Comment then post_path(notification.subject.post, anchor: ActionView::RecordIdentifier.dom_id(notification.subject))
      when Post then post_path(notification.subject)
      when Follow then follows_path
      else notifications_path
      end
    end
end
