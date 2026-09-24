class PostsController < ApplicationController
  allow_unauthenticated_access only: :show
  before_action :set_post, only: %i[ show edit update publish destroy ]
  before_action :require_author, only: %i[ edit update publish ]
  before_action :require_permission_to_delete, only: :destroy

  def show
    @comments = visibility.visible_comments(@post).includes(:actor)
    @comment = Comment.new(post: @post)

    # Signed out, we are already only here because the post is public; whether
    # it is also *findable* is the author's rung to decide.
    allow_indexing_by @post.actor
  end

  # Also where the share sheet lands: the manifest points share_target at this
  # action, so "share to Kith" from another app opens the composer with the
  # link already in it. It only ever prefills — nothing is written until the
  # member presses the button, and the audience is theirs to pick as always.
  def new
    @post = current_actor.posts.build(shared_post_attributes)
  end

  def create
    @post = current_actor.posts.build(post_params)
    @post.published_at = Time.current unless draft_requested?

    if @post.save
      redirect_to @post, notice: @post.draft? ? "Saved as a draft." : "Posted."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  # One form, two buttons: "Save as draft" sends `draft`, and anything else
  # from a draft means post it. A post that is already out stays out — there is
  # no unpublishing, because the reader has already seen it.
  def update
    was_draft = @post.draft?

    @post.assign_attributes(was_draft ? post_params : post_params.except(:audience))
    @post.published_at = Time.current if was_draft && !draft_requested?

    if @post.save
      redirect_to @post, notice: saved_notice(was_draft)
    else
      render :edit, status: :unprocessable_content
    end
  end

  # A draft also goes out from its own permalink, which is where the author is
  # when they read it back and decide it is finished.
  def publish
    @post.publish!
    redirect_to @post, notice: "Posted."
  end

  # Nothing is soft-deleted. The photos go with it.
  def destroy
    @post.destroy
    redirect_to root_path, notice: "Deleted.", status: :see_other
  end

  private
    # 404 rather than 403 for a post you may not see: a 403 confirms it exists.
    def set_post
      @post = Post.find(params[:id])
      head :not_found unless visibility.post?(@post)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def require_author
      head :not_found unless authority.edit_post?(@post)
    end

    def require_permission_to_delete
      head :not_found unless authority.delete_post?(@post)
    end

    # A share arrives as three loose strings, and which of them holds what is up
    # to the sending app: Android puts a link in `text` about as often as in
    # `url`, and frequently in both. Treat them as text, not markup, and don't
    # say the same URL twice.
    def shared_post_attributes
      title = params[:title].to_s.strip.truncate(Post::TITLE_LIMIT)
      text  = params[:text].to_s.strip
      url   = params[:url].to_s.strip

      body = [ text, (url unless url.blank? || text.include?(url)) ].compact_blank.join("\n\n")

      { title: title.presence, body: Post.paragraphs(body).presence }.compact
    end

    def post_params
      params.expect(post: [ :title, :body, :audience ])
    end

    def draft_requested? = params[:draft].present?

    def saved_notice(was_draft)
      return "Posted." if was_draft && @post.published?

      @post.draft? ? "Saved as a draft." : "Saved."
    end
end
