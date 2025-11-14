class GmailConnectionsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    current_user.disconnect_gmail!
    redirect_to profile_path, notice: "Gmail déconnecté."
  end
end
