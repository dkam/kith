# Claiming an empty instance. The credential is the setup code printed on the
# server's console, and this controller exists only while nobody has joined:
# see Setup.
class SetupController < ApplicationController
  allow_unauthenticated_access
  before_action :ensure_setup_open
  before_action :build_member

  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to setup_path, alert: "Try again later." }

  def new
  end

  def create
    return wrong_code unless Setup.correct?(params[:code])

    @member = Member.create_first(**member_params)

    if @member.persisted?
      start_new_session_for @member
      redirect_to settings_path, notice: "Kith is yours. Everyone else arrives by invitation."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # 404 rather than 403, like everything else: a different status would tell
    # a stranger whether this instance has anybody in it.
    def ensure_setup_open
      head :not_found unless Setup.open?
    end

    # Re-rendering the form keeps everything they typed except the passwords.
    def build_member
      @member = Member.new(member_params.except(:handle, :display_name, :password, :password_confirmation))
      @member.build_actor(type: "LocalActor", handle: member_params[:handle], display_name: member_params[:display_name])
    end

    def wrong_code
      @member.errors.add(:base, "That code doesn't match the one on the server's console.")
      render :new, status: :unprocessable_content
    end

    # Always the same five keys, even on an empty post, so the form can be
    # rebuilt from whatever arrived.
    def member_params
      permitted = params.fetch(:member, ActionController::Parameters.new)
        .permit(:email_address, :password, :password_confirmation, actor_attributes: [ :handle, :display_name ])

      @member_params ||= {
        email_address: permitted[:email_address],
        password: permitted[:password],
        password_confirmation: permitted[:password_confirmation],
        handle: permitted.dig(:actor_attributes, :handle),
        display_name: permitted.dig(:actor_attributes, :display_name)
      }
    end
end
