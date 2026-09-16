class CommentsController < ApplicationController
  before_action :set_post, only: :create
  before_action :set_comment, only: :destroy

  def create
    @comment = @post.comments.build(comment_params.merge(actor: current_actor))

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @post }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_content }
        format.html { redirect_to @post, alert: @comment.errors.full_messages.to_sentence }
      end
    end
  end

  # Your own comment, any comment on your own post, or — for a moderator —
  # any comment they can already see. See Authority.
  def destroy
    @post = @comment.post
    @comment.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @post, notice: "Deleted." }
    end
  end

  private
    def set_post
      @post = Post.find(params[:post_id])
      head :not_found unless visibility.post?(@post)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def set_comment
      comment = Comment.find(params[:id])

      head :not_found and return unless authority.delete_comment?(comment)

      @comment = comment
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def comment_params
      params.expect(comment: [ :body ])
    end
end
