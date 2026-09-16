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

    redirect_to root_path, notice: "All marked as read."
  end
end
