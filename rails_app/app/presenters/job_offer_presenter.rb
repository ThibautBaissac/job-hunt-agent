class JobOfferPresenter
  SOURCE_LABELS = {
    "linkedin" => "LinkedIn",
    "wttj" => "Welcome to the Jungle",
    "other" => "Autre"
  }.freeze

  def initialize(job_offer)
    @job_offer = job_offer
  end

  def source_label
    SOURCE_LABELS.fetch(job_offer.source, job_offer.source.titleize)
  end

  def tech_stack
    Array(job_offer.tech_stack).compact_blank
  end

  def analysis_status
    return "Analyse IA disponible" if job_offer.analysis_available?

    "Analyse en cours"
  end

  def analysis_available?
    job_offer.analysis_available?
  end

  def summary
    job_offer.summary.presence
  end

  def description
    job_offer.raw_description
  end

  def job_offer
    @job_offer
  end
end
