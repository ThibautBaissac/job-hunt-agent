module CvImporters
  class Create
    class Error < StandardError; end

    def initialize(user:, params:, text_extractor: TextExtractor)
      @user = user
      @params = params
      @text_extractor = text_extractor
    end

    def call
      body_text = resolve_body_text
      raise Error, "Le CV doit contenir du texte" if body_text.blank?

      Cv.transaction do
        deactivate_previous_active_cv

        cv = user.cvs.create!(
          body_text: body_text.strip,
          active: true,
          import_method: import_method,
          source_filename: source_filename,
          title: params[:title].presence
        )

        attach_document(cv)

        cv
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.to_sentence
    rescue CvImporters::ExtractionError => e
      raise Error, e.message
    end

    private

    attr_reader :user, :params, :text_extractor

    def deactivate_previous_active_cv
      user.cvs.where(active: true).update_all(active: false)
    end

    def attach_document(cv)
      return unless file

      cv.document.attach(file)
    end

    def resolve_body_text
      if file.present?
        text_extractor.new(file).call
      else
        params[:body_text].to_s
      end
    end

    def file
      params[:document]
    end

    def import_method
      file.present? ? "upload" : "paste"
    end

    def source_filename
      return unless file

      file.original_filename
    end
  end
end
