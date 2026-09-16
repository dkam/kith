# Claiming an invite. This is the only way a member is created, outside the
# kith:first_member rake task.
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_authenticated_member
  before_action :set_invite

  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to join_path(params[:code]), alert: "Try again later." }

  def new
    @member = Member.new
    @member.build_actor(type: "LocalActor")
  end

  def create
    @member = Member.claim(@invite, **registration_params)

    if @member.persisted?
      start_new_session_for @member
      redirect_to root_path, notice: "Welcome to Kith. This is your corner of it."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_invite
      @invite = Invite.open.find_by(code: params[:code])

      redirect_to new_session_path, alert: "That invite has been used already, or has expired." if @invite.nil?
    end

    def redirect_authenticated_member
      redirect_to root_path if authenticated?
    end

    def registration_params
      permitted = params.expect(member: [ :email_address, :password, :password_confirmation, { actor_attributes: [ :handle, :display_name ] } ])

      {
        email_address: permitted[:email_address],
        password: permitted[:password],
        password_confirmation: permitted[:password_confirmation],
        handle: permitted.dig(:actor_attributes, :handle),
        display_name: permitted.dig(:actor_attributes, :display_name)
      }
    end
end
