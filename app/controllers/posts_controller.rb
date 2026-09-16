class PostsController < ApplicationController
  allow_unauthenticated_access only: :show
  before_action :set_post, only: %i[ show edit update destroy ]
  before_action :require_author, only: %i[ edit update ]
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
      head :not_found unless authority.edit_post?(@post)
    end

    def require_permission_to_delete
      head :not_found unless authority.delete_post?(@post)
    end

    def post_params
      params.expect(post: [ :title, :body, :audience ])
    end
end
