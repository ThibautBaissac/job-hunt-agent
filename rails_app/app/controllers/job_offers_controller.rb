class JobOffersController < ApplicationController
  before_action :set_job_offer, only: %i[show analyze]

  def index
    @job_offers = current_user.job_offers.recent_first
  end

  def new
    @import_form = JobOffers::UrlImportForm.new(user: current_user)
  end

  def create
    @import_form = JobOffers::UrlImportForm.new(
      user: current_user,
      attributes: job_offer_import_params
    )

    if @import_form.submit
      redirect_to job_offer_path(@import_form.job_offer), notice: "Offre importée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @presenter = JobOfferPresenter.new(@job_offer)
    @analysis_stream_name = analysis_stream_name_for(@job_offer)
  end

  def analyze
    OfferAnalysisJob.perform_later(@job_offer.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@job_offer, :analysis),
          partial: "job_offers/analysis_loading",
          locals: { job_offer: @job_offer, presenter: JobOfferPresenter.new(@job_offer) }
        )
      end

      format.html do
        redirect_to job_offer_path(@job_offer), notice: "Analyse relancée. Les résultats apparaîtront dès qu'ils seront prêts."
      end
    end
  end

  def new_manual
    @manual_form = JobOffers::ManualImportForm.new(user: current_user)
  end

  def create_manual
    @manual_form = JobOffers::ManualImportForm.new(
      user: current_user,
      attributes: job_offer_manual_params
    )

    if @manual_form.submit
      redirect_to job_offer_path(@manual_form.job_offer), notice: "Offre créée avec succès."
    else
      render :new_manual, status: :unprocessable_entity
    end
  end

  private

  def set_job_offer
    @job_offer = current_user.job_offers.find(params[:id])
  end

  def job_offer_import_params
    params.fetch(:job_offer_import, {}).permit(:url)
  end

  def job_offer_manual_params
    params.fetch(:job_offer_manual, {}).permit(
      :title,
      :company_name,
      :location,
      :raw_description,
      :source_url,
      :tech_stack_input
    )
  end

  def analysis_stream_name_for(job_offer)
    "job_offer_analysis_#{job_offer.id}"
  end
end
