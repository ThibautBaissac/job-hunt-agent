module CvVersions
  class CreateFromAnalysis
    class Error < StandardError; end

    def initialize(user:, source_cv:, params:)
      @user = user
      @source_cv = source_cv
      @params = params
    end

    def call
      body_text = params[:body_text].to_s.strip
      raise Error, "Le contenu du CV est requis." if body_text.blank?

      CvImporters::Create.new(
        user: user,
        params: {
          body_text: body_text,
          title: params[:title].presence || default_title
        }
      ).call
    rescue CvImporters::Create::Error => e
      raise Error, e.message
    end

    private

    attr_reader :user, :source_cv, :params

    def default_title
      "CV optimisé - #{I18n.l(Time.current, format: :short)}"
    end
  end
end
