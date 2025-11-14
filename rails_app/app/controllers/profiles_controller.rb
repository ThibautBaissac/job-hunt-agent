class ProfilesController < ApplicationController
  before_action :set_profile

  helper_method :language_options, :ai_tone_options

  def show; end

  def edit; end

  def update
    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profil mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile
    @profile = current_user.profile || current_user.create_profile!
  end

  def profile_params
    params.require(:profile).permit(
      :full_name,
      :title,
      :city,
      :github_url,
      :linkedin_url,
      :default_signature,
      :language,
      :ai_tone
    )
  end

  def language_options
    Profile::LANGUAGE_OPTIONS.map do |key, value|
      [ I18n.t("profiles.languages.#{key}", default: key.to_s.humanize), value ]
    end
  end

  def ai_tone_options
    Profile::AI_TONE_OPTIONS.map do |key, value|
      [ I18n.t("profiles.ai_tones.#{key}", default: key.to_s.humanize), value ]
    end
  end
end
