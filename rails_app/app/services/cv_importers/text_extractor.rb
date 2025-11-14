require "docx"
require "pdf-reader"
require "zip"

module CvImporters
  class ExtractionError < StandardError; end

  class TextExtractor
    SUPPORTED_TYPES = {
      "application/pdf" => :extract_pdf,
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => :extract_docx
    }.freeze

    def initialize(uploaded_file)
      @uploaded_file = uploaded_file
    end

    def call
      extractor = SUPPORTED_TYPES[content_type]
      raise ExtractionError, "Format de fichier non pris en charge" unless extractor

      send(extractor)
    rescue PDF::Reader::MalformedPDFError, Zip::Error => e
      raise ExtractionError, "Impossible de lire le fichier : #{e.message}"
    end

    private

    attr_reader :uploaded_file

    def content_type
      uploaded_file.content_type
    end

    def extract_pdf
      PDF::Reader.new(uploaded_file.tempfile).pages.map(&:text).join("\n").strip
    end

    def extract_docx
      document = Docx::Document.open(uploaded_file.tempfile)
      document.paragraphs.map(&:text).join("\n").strip
    end
  end
end
