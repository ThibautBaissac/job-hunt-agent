module Cvs
  class OptimizationsController < ApplicationController
    before_action :set_cv

    def new
      redirect_to(cvs_path, alert: "Analyse nécessaire avant d'optimiser votre CV.") and return unless @cv.analysis_available?

      @optimized_body = params.fetch(:body_text, @cv.body_text)
      @suggestions = @cv.analysis_suggestions
    end

    def create
      service = CvVersions::CreateFromAnalysis.new(
        user: current_user,
        source_cv: @cv,
        params: optimization_params
      )

      service.call

      redirect_to cvs_path, notice: "Une nouvelle version optimisée de votre CV a été créée."
    rescue CvVersions::CreateFromAnalysis::Error => e
      @optimized_body = optimization_params[:body_text]
      @suggestions = @cv.analysis_suggestions
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    private

    def set_cv
      @cv = current_user.cvs.find(params[:cv_id])
    end

    def optimization_params
      params.require(:optimization).permit(:body_text, :title)
    end
  end
end
