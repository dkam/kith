class InvitesController < ApplicationController
  def index
    @invites = current_member.issued_invites.newest_first
  end

  def create
    invite = current_member.issued_invites.create!

    redirect_to invites_path, notice: "Invite ready. Send the link to one person — it only works once."
  end

  def destroy
    invite = current_member.issued_invites.unclaimed.find(params[:id])
    invite.destroy

    redirect_to invites_path, notice: "Invite revoked."
  end
end
