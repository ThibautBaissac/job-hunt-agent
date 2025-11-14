class CvPresenter
  def initialize(user)
    @user = user
  end

  def active_cv
    @active_cv ||= user.active_cv
  end

  def other_cvs
    return user.cvs.recent_first unless active_cv

    user.cvs.where.not(id: active_cv.id).recent_first
  end

  def recent_cvs
    user.cvs.recent_first
  end

  def analysis_stream_name(cv = active_cv)
    return unless cv

    "cv_analysis_#{cv.id}"
  end

  def analysis_sections(cv = active_cv)
    return { strengths: [], weaknesses: [], suggestions: [], summary: nil } unless cv&.analysis_available?

    {
      strengths: cv.analysis_forces,
      weaknesses: cv.analysis_weaknesses,
      suggestions: cv.analysis_suggestions,
      summary: cv.analysis_summary
    }
  end

  private

  attr_reader :user
end
