module CvVersions
  class Activate
    class Error < StandardError; end

    def initialize(user:, cv:)
      @user = user
      @cv = cv
    end

    def call
      raise Error, "CV introuvable." unless cv.user_id == user.id

      Cv.transaction do
        user.cvs.where(active: true).where.not(id: cv.id).update_all(active: false)
        cv.update!(active: true)
      end

      cv
    end

    private

    attr_reader :user, :cv
  end
end
