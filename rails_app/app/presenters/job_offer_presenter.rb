class JobOfferPresenter
  SOURCE_LABELS = {
    "linkedin" => "LinkedIn",
    "wttj" => "Welcome to the Jungle",
    "other" => "Autre"
  }.freeze

  BACKEND_OPTIONS = {
    "rails" => {
      label: "Rails LLM",
      badge_classes: "bg-indigo-100 text-indigo-800"
    },
    "python" => {
      label: "Agent API",
      badge_classes: "bg-emerald-100 text-emerald-800"
    }
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

  def keywords
    Array(job_offer.keywords).compact_blank
  end

  def analysis_status
    return "Analyse IA disponible" if job_offer.analysis_available?

    "Analyse en cours"
  end

  def analysis_backend_label
    option_for(job_offer.analysis_backend)[:label]
  end

  def analysis_backend_badge_classes
    backend_badge_classes_for(job_offer.analysis_backend)
  end

  def backend_label_for(mode)
    option_for(mode)[:label]
  end

  def backend_badge_classes_for(mode)
    option_for(mode)[:badge_classes]
  end

  def available_backends
    BACKEND_OPTIONS.map do |key, config|
      { key: key, label: config[:label] }
    end
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

  def option_for(mode)
    key = mode.to_s.presence
    BACKEND_OPTIONS.fetch(key, nil) || { label: "Flux non défini", badge_classes: "bg-slate-200 text-slate-600" }
  end
end
