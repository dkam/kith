# Materialises a post into the feeds of everyone who may read it.
#
# Fan-out on write, because it is forty people and the alternative — a join
# across follows on every page load — buys nothing at this size and gives the
# reader nowhere to keep their unread state.
#
# The audience is resolved through Visibility, the same as everywhere else, so
# a post cannot reach a feed it would not reach through a query.
class FanOutJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(subject)
    case subject
    when Post then fan_out_post(subject)
    when Follow then fan_in_follow(subject)
    end
  end

  private
    # A new post reaches its author and everyone whose follow has been accepted.
    # A draft reaches nobody, including its author's own feed: the feed is what
    # other people have posted, and a post that is still being written has not
    # been posted. The guard is here as well as in the callback because this
    # job is the only thing that writes into other people's feeds.
    def fan_out_post(post)
      return if post.draft?

      member_ids = Member.where(actor_id: reader_actor_ids_for(post)).pluck(:id)
      insert_items member_ids.map { |member_id| { member_id:, post_id: post.id, posted_at: post.published_at } }
    end

    # A newly accepted follow back-fills the follower's feed with what they can
    # now see, so accepting does not leave them staring at an empty page.
    def fan_in_follow(follow)
      return unless follow.accepted?

      member = Member.find_by(actor_id: follow.follower_actor_id)
      return if member.nil?

      posts = Visibility.new(follow.follower_actor)
        .visible_posts(Post.by(follow.followed_actor))
        .newest_first
        .limit(BACKFILL_LIMIT)

      insert_items posts.map { |post| { member_id: member.id, post_id: post.id, posted_at: post.published_at } }
    end

    BACKFILL_LIMIT = 50

    def reader_actor_ids_for(post)
      readers = [ post.actor_id ]
      readers += Follow.accepted.where(followed_actor_id: post.actor_id).pluck(:follower_actor_id)
      readers.uniq
    end

    # unique_by leans on the (member_id, post_id) index: fanning out twice, or
    # back-filling a post the reader already has, is a no-op rather than a
    # duplicate row.
    def insert_items(rows)
      return if rows.empty?

      now = Time.current
      FeedItem.insert_all(rows.map { |row| row.merge(created_at: now, updated_at: now) },
                          unique_by: %i[ member_id post_id ])
    end
end
