class PostsController < ApplicationController
  allow_unauthenticated_access only: :show
  before_action :set_post, only: %i[ show edit update publish destroy ]
  before_action :require_author, only: %i[ edit update publish ]
  before_action :require_permission_to_delete, only: :destroy

  def show
    @comments = visibility.visible_comments(@post).includes(:actor)
    @comment = Comment.new(post: @post)
  end

  def new
    @post = current_actor.posts.build
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

    def post_params
      params.expect(post: [ :title, :body, :audience ])
    end

    def draft_requested? = params[:draft].present?

    def saved_notice(was_draft)
      return "Posted." if was_draft && @post.published?

      @post.draft? ? "Saved as a draft." : "Saved."
    end
end
