# Marking as read. Called by the reader as posts scroll past.
class FeedItemsController < ApplicationController
  def update
    item = current_member.feed_items.find(params[:id])
    item.read!

    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def read_all
    current_member.feed_items.unread.update_all(read_at: Time.current, updated_at: Time.current)

    # A redirect back to the page you are already on pushes a second copy of
    # it onto an app's navigation stack. `refresh_or_redirect_to` is
    # turbo-rails' answer: the app refreshes the screen it is on, the web gets
    # the redirect it always got.
    refresh_or_redirect_to root_path, notice: "All marked as read."
  end
end
