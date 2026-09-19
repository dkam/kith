class PostsController < ApplicationController
  allow_unauthenticated_access only: :show
  before_action :set_post, only: %i[ show edit update destroy ]
  before_action :require_author, only: %i[ edit update destroy ]

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

    if @post.save
      redirect_to @post, notice: "Posted."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @post.update(post_params.except(:audience))
      redirect_to @post, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
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
      head :not_found unless @post.actor_id == current_actor&.id
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
end
