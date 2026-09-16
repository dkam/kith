class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_member_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    if member = Member.find_by(email_address: params[:email_address].to_s.strip.downcase)
      PasswordsMailer.reset(member).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if a member with that email address exists)."
  end

  def edit
  end

  def update
    if @member.update(params.permit(:password, :password_confirmation))
      @member.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def set_member_by_token
      @member = Member.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
