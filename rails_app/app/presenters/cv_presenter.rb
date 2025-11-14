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

  private

  attr_reader :user
end
