require "rails_helper"
require "rack/test"

RSpec.describe CvImporters::Create do
  let(:user) { create(:user) }

  describe "#call" do
    it "creates an active CV from pasted text" do
      previous_active = create(:cv, :active, user: user)

      service = described_class.new(user: user, params: { body_text: "Nouveau contenu" })
      result = service.call

      expect(result).to be_active
      expect(result.body_text).to include("Nouveau contenu")
      expect(user.reload.active_cv).to eq(result)
      expect(previous_active.reload).not_to be_active
    end

    it "raises an error when no text is provided" do
      service = described_class.new(user: user, params: { body_text: "" })

      expect { service.call }.to raise_error(described_class::Error, "Le CV doit contenir du texte")
    end

    it "creates an active CV from an uploaded file" do
      Tempfile.create([ "cv", ".pdf" ]) do |tempfile|
        tempfile.write("fake pdf content")
        tempfile.rewind

        uploaded_file = Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true)
        extractor_class = class_double(CvImporters::TextExtractor)
        extractor_instance = instance_double(CvImporters::TextExtractor)

        allow(extractor_class).to receive(:new).with(uploaded_file).and_return(extractor_instance)
        allow(extractor_instance).to receive(:call).and_return("Texte extrait")

        service = described_class.new(user: user, params: { document: uploaded_file }, text_extractor: extractor_class)
        result = service.call

        expect(result).to be_active
        expect(result.body_text).to eq("Texte extrait")
        expect(result.import_method).to eq("upload")
        expect(result.source_filename).to eq(File.basename(tempfile.path))
        expect(result.document).to be_attached
      end
    end

    it "propagates extraction errors as service errors" do
      tempfile = Tempfile.new([ "cv", ".pdf" ])
      uploaded_file = Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true)
      extractor_class = class_double(CvImporters::TextExtractor)
      extractor_instance = instance_double(CvImporters::TextExtractor)

      allow(extractor_class).to receive(:new).with(uploaded_file).and_return(extractor_instance)
      allow(extractor_instance).to receive(:call).and_raise(CvImporters::ExtractionError, "invalid")

      service = described_class.new(user: user, params: { document: uploaded_file }, text_extractor: extractor_class)

      expect { service.call }.to raise_error(described_class::Error, "invalid")
    ensure
      tempfile.close!
    end
  end
end
