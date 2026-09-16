class InvitesController < ApplicationController
  def index
    @invites = current_member.issued_invites.newest_first
  end

  # Checked here as well as hidden in the view, because a form that is not on
  # the page is not a rule.
  def create
    unless authority.issue_invite?
      redirect_to invites_path, alert: refusal and return
    end

    current_member.issued_invites.create!

    redirect_to invites_path, notice: "Invite ready. Send the link to one person — it only works once."
  end

  def destroy
    invite = current_member.issued_invites.unclaimed.find(params[:id])
    invite.destroy

    redirect_to invites_path, notice: "Invite revoked."
  end

  private
    def refusal
      current_instance.closed_because || "You have no invites left. Ask an admin for more."
    end
end
