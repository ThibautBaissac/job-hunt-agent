class CvsController < ApplicationController
  def index
    @presenter = CvPresenter.new(current_user)
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

  private

  def cv_params
    params.require(:cv).permit(:body_text, :document)
  end
end
