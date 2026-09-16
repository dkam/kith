# The reader. Strictly chronological, never ranked.
class FeedController < ApplicationController
  PAGE_SIZE = 20

  def show
    items = current_member.feed_items.before(params[:before]).newest_first
      .includes(post: [ :actor, { rich_text_body: { embeds_attachments: :blob } } ])
      .limit(PAGE_SIZE + 1)
      .to_a

    @more = items.size > PAGE_SIZE
    @items = items.first(PAGE_SIZE)
    @next_cursor = @items.last&.id

    # Belt and braces. Feed items are materialised through Visibility, but a
    # follow can be withdrawn after the fan-out, and the feed must not be the
    # one page in the app that shows a post the policy would refuse.
    @items.select! { |item| visibility.post?(item.post) }

    render :show, layout: !turbo_frame_request?
  end
end
