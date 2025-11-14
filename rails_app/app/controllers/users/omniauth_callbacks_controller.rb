class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    return redirect_to new_user_session_path, alert: "Connectez-vous pour lier Gmail." unless current_user

    auth = request.env["omniauth.auth"]
    if auth.blank?
      redirect_to profile_path, alert: "Impossible de récupérer les informations Google."
      return
    end

    if auth.info.email != current_user.email
      redirect_to profile_path, alert: "L'email Google ne correspond pas à votre compte."
      return
    end

    User.connect_google_account!(user: current_user, auth: auth)

    redirect_to profile_path, notice: "Gmail connecté avec succès."
  rescue StandardError => e
    Rails.logger.error("Gmail OAuth error: #{e.class} - #{e.message}")
    redirect_to profile_path, alert: "Erreur lors de la connexion Gmail. Merci de réessayer."
  end

  def failure
    redirect_to profile_path, alert: "Connexion Gmail annulée."
  end
end
