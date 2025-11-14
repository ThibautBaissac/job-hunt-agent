class CvsController < ApplicationController
  before_action :set_cv, only: %i[show analyze activate]

  def index
    @presenter = CvPresenter.new(current_user)
  end

  def show
    @analysis_stream_name = analysis_stream_name_for(@cv)
  end

  def new
    @cv = current_user.cvs.build
  end

  def create
    @cv = CvImporters::Create.new(user: current_user, params: cv_params).call
    redirect_to cvs_path, notice: "Votre CV principal a été mis à jour."
  rescue CvImporters::Create::Error => e
    @cv = current_user.cvs.build(cv_params)
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def analyze
    CvAnalysisJob.perform_later(@cv.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@cv, :analysis),
          partial: "cvs/analysis_loading",
          locals: { cv: @cv }
        )
      end
      format.html do
        redirect_to cvs_path, notice: "Analyse en cours. Les résultats apparaîtront ici."
      end
    end
  end

  def activate
    CvVersions::Activate.new(user: current_user, cv: @cv).call
    redirect_to cvs_path, notice: "Cette version est maintenant votre CV principal."
  rescue CvVersions::Activate::Error => e
    redirect_to cvs_path, alert: e.message
  end

  private

  def cv_params
    params.require(:cv).permit(:body_text, :document, :title)
  end

  def set_cv
    @cv = current_user.cvs.find(params[:id])
  end

  def analysis_stream_name_for(cv)
    "cv_analysis_#{cv.id}"
  end
end
