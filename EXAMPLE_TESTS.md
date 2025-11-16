# Example Test Implementations

This document provides copy-paste ready test examples for the highest priority gaps.

## 1. Rails: ScraperClient Test (CRITICAL)

**File:** `/home/user/job-hunt-agent/rails_app/spec/services/offer_importers/scraper_client_spec.rb`

```ruby
require "rails_helper"

RSpec.describe OfferImporters::ScraperClient do
  describe "#fetch" do
    let(:base_url) { "http://localhost:8002" }
    let(:url) { "https://www.linkedin.com/jobs/view/123" }
    let(:client) { described_class.new(base_url: base_url) }

    context "when response is successful" do
      let(:response_body) do
        {
          "title" => "Senior Ruby Developer",
          "company" => "Acme Inc",
          "location" => "Paris, France",
          "description" => "Long job description...",
          "platform" => "linkedin"
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it "returns parsed job data" do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(response)

        result = client.fetch(url)

        expect(result[:title]).to eq("Senior Ruby Developer")
        expect(result[:company]).to eq("Acme Inc")
        expect(result[:platform]).to eq("linkedin")
      end
    end

    context "when response is a string" do
      let(:response_string) do
        '{"title":"Backend Dev","company":"TechCorp","location":"Remote","description":"Build APIs","platform":"wttj"}'
      end
      let(:response) { instance_double(Faraday::Response, body: response_string) }

      it "parses JSON string response" do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(response)

        result = client.fetch(url)

        expect(result[:title]).to eq("Backend Dev")
        expect(result[:company]).to eq("TechCorp")
      end
    end

    context "when response has missing fields" do
      let(:response_body) do
        {
          "title" => "Developer",
          # Missing company and description
          "platform" => "linkedin"
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it "raises an error for missing required fields" do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(response)

        expect {
          client.fetch(url)
        }.to raise_error(described_class::Error, /company|description/)
      end
    end

    context "when Faraday connection times out" do
      it "wraps timeout errors" do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(
          Faraday::TimeoutError.new("timeout")
        )

        expect {
          client.fetch(url)
        }.to raise_error(described_class::Error, /Scraper API indisponible/)
      end
    end

    context "when Faraday returns connection error" do
      it "wraps connection errors" do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(
          Faraday::ConnectionFailed.new("Connection refused")
        )

        expect {
          client.fetch(url)
        }.to raise_error(described_class::Error, /Scraper API indisponible/)
      end
    end

    context "when response body is invalid JSON" do
      let(:response) { instance_double(Faraday::Response, body: "invalid json {") }

      it "raises an error" do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(response)

        expect {
          client.fetch(url)
        }.to raise_error(described_class::Error, /illisible/)
      end
    end

    context "when base_url is not configured" do
      it "raises an error on initialization" do
        expect {
          described_class.new(base_url: nil)
        }.to raise_error(described_class::Error, /SCRAPER_API_URL/)
      end
    end
  end
end
```

---

## 2. Rails: TextExtractor Test (CRITICAL)

**File:** `/home/user/job-hunt-agent/rails_app/spec/services/cv_importers/text_extractor_spec.rb`

```ruby
require "rails_helper"

RSpec.describe CvImporters::TextExtractor do
  describe "#call" do
    let(:extractor) { described_class.new(file) }

    context "when file is a PDF" do
      let(:file) do
        Rack::Test::UploadedFile.new(
          "spec/fixtures/sample_cv.pdf",
          "application/pdf"
        )
      end

      it "extracts text from PDF" do
        # Assumes spec/fixtures/sample_cv.pdf exists with "John Doe" in it
        text = extractor.call

        expect(text).to be_present
        expect(text).to include("John Doe")
      end
    end

    context "when file is a DOCX" do
      let(:file) do
        Rack::Test::UploadedFile.new(
          "spec/fixtures/sample_cv.docx",
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
      end

      it "extracts text from DOCX" do
        # Assumes spec/fixtures/sample_cv.docx exists
        text = extractor.call

        expect(text).to be_present
        expect(text.length).to be > 0
      end
    end

    context "when file is unsupported format" do
      let(:file) do
        Rack::Test::UploadedFile.new(
          "spec/fixtures/image.jpg",
          "image/jpeg"
        )
      end

      it "raises an extraction error" do
        expect {
          extractor.call
        }.to raise_error(CvImporters::ExtractionError)
      end
    end

    context "when file is empty" do
      let(:tempfile) { Tempfile.new(["empty", ".pdf"]) }
      let(:file) do
        tempfile.write("")
        tempfile.rewind
        Rack::Test::UploadedFile.new(tempfile.path, "application/pdf")
      end

      after { tempfile.close! }

      it "extracts empty text" do
        text = extractor.call

        # Empty PDF should return empty string, not error
        expect(text).to eq("")
      end
    end

    context "when PDF is corrupted" do
      let(:tempfile) { Tempfile.new(["corrupt", ".pdf"]) }
      let(:file) do
        tempfile.write("not a pdf")
        tempfile.rewind
        Rack::Test::UploadedFile.new(tempfile.path, "application/pdf")
      end

      after { tempfile.close! }

      it "raises an extraction error" do
        expect {
          extractor.call
        }.to raise_error(CvImporters::ExtractionError)
      end
    end
  end
end
```

---

## 3. Rails: CvAnalysisJob Test (CRITICAL)

**File:** `/home/user/job-hunt-agent/rails_app/spec/jobs/cv_analysis_job_spec.rb`

```ruby
require "rails_helper"

RSpec.describe CvAnalysisJob, type: :job do
  let(:cv) { create(:cv, :active) }
  let(:analyzer) { instance_double(Ai::CvAnalyzer) }

  before do
    allow(Ai::CvAnalyzer).to receive(:new).and_return(analyzer)
    allow(analyzer).to receive(:call).and_return(nil)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(ApplicationController).to receive(:render).and_return("<div>Mock</div>")
  end

  describe "#perform" do
    it "analyzes the CV" do
      described_class.new.perform(cv.id)

      expect(Ai::CvAnalyzer).to have_received(:new).with(
        cv: cv,
        streamer: an_instance_of(Proc),
        client: anything
      )
      expect(analyzer).to have_received(:call)
    end

    it "passes a streamer callback" do
      streamer_calls = []

      expect(Ai::CvAnalyzer).to receive(:new) do |args|
        # Capture the streamer and call it
        streamer_calls << args[:streamer]
        analyzer
      end

      described_class.new.perform(cv.id)

      # Verify streamer was captured
      expect(streamer_calls).to be_present
    end

    context "when analysis succeeds" do
      before do
        allow(analyzer).to receive(:call) do
          cv.update!(
            analysis_summary: "Strong profile",
            analysis_forces: ["Technical skills"],
            analyzed_at: Time.current
          )
        end
      end

      it "broadcasts the analysis panel" do
        described_class.new.perform(cv.id)

        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
          "cv_analysis_#{cv.id}",
          hash_including(target: anything)
        )
      end
    end

    context "when analysis fails" do
      before do
        allow(analyzer).to receive(:call).and_raise(
          Ai::CvAnalyzer::Error,
          "Analysis failed"
        )
      end

      it "broadcasts error message" do
        described_class.new.perform(cv.id)

        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
          "cv_analysis_#{cv.id}",
          hash_including(target: anything)
        )
      end

      it "does not raise the error" do
        expect {
          described_class.new.perform(cv.id)
        }.not_to raise_error
      end
    end

    it "reloads the CV to get updated data" do
      described_class.new.perform(cv.id)

      # Verify CV was reloaded (it's reloaded in the job)
      expect(Ai::CvAnalyzer).to have_received(:new)
    end
  end
end
```

---

## 4. Rails: ManualImportForm Test (HIGH)

**File:** `/home/user/job-hunt-agent/rails_app/spec/forms/job_offers/manual_import_form_spec.rb`

```ruby
require "rails_helper"

RSpec.describe JobOffers::ManualImportForm do
  let(:user) { create(:user) }
  let(:attributes) do
    {
      title: "Senior Developer",
      company_name: "Acme Inc",
      location: "Paris",
      raw_description: "Long job description...",
      source_url: "https://example.com/job/123"
    }
  end
  let(:form) { described_class.new(user: user, attributes: attributes) }

  describe "validations" do
    it { expect(form).to validate_presence_of(:title) }
    it { expect(form).to validate_presence_of(:company_name) }
    it { expect(form).to validate_presence_of(:raw_description) }

    context "with invalid URL" do
      before { form.source_url = "not-a-url" }

      it "is invalid" do
        expect(form).not_to be_valid
        expect(form.errors[:source_url]).to be_present
      end
    end

    context "with valid URL" do
      before { form.source_url = "https://example.com" }

      it "is valid" do
        expect(form).to be_valid
      end
    end

    context "with blank URL" do
      before { form.source_url = "" }

      it "is valid (optional field)" do
        expect(form).to be_valid
      end
    end
  end

  describe "#submit" do
    context "with valid data" do
      it "creates a job offer" do
        expect {
          form.submit
        }.to change(JobOffer, :count).by(1)
      end

      it "creates offer with correct attributes" do
        form.submit

        job = user.job_offers.last
        expect(job.title).to eq("Senior Developer")
        expect(job.company_name).to eq("Acme Inc")
        expect(job.source).to eq("other")
      end

      it "enqueues an analysis job" do
        expect {
          form.submit
        }.to have_enqueued_job(OfferAnalysisJob)
      end

      it "returns true" do
        result = form.submit

        expect(result).to be(true)
      end

      it "sets the job_offer attribute" do
        form.submit

        expect(form.job_offer).to be_persisted
        expect(form.job_offer.user).to eq(user)
      end
    end

    context "with invalid data" do
      before { form.title = "" }

      it "does not create a job offer" do
        expect {
          form.submit
        }.not_to change(JobOffer, :count)
      end

      it "adds error to base" do
        form.submit

        expect(form.errors[:base]).to be_present
      end

      it "returns false" do
        result = form.submit

        expect(result).to be(false)
      end
    end

    context "with tech stack input" do
      before { form.tech_stack_input = "Ruby, Rails; PostgreSQL\nDocker" }

      it "parses comma-separated tech stack" do
        form.submit

        job = user.job_offers.last
        expect(job.tech_stack).to include("Ruby", "Rails", "PostgreSQL", "Docker")
      end

      it "cleans up whitespace" do
        form.submit

        job = user.job_offers.last
        expect(job.tech_stack).not_to include("", " Ruby")
      end
    end

    context "with blank tech stack" do
      before { form.tech_stack_input = "" }

      it "creates job with empty tech stack" do
        form.submit

        job = user.job_offers.last
        expect(job.tech_stack).to eq([])
      end
    end
  end
end
```

---

## 5. Rails: CvPresenter Test (MEDIUM)

**File:** `/home/user/job-hunt-agent/rails_app/spec/presenters/cv_presenter_spec.rb`

```ruby
require "rails_helper"

RSpec.describe CvPresenter do
  let(:user) { create(:user) }
  let(:presenter) { described_class.new(user) }

  describe "#active_cv" do
    context "when user has an active CV" do
      let!(:active_cv) { create(:cv, :active, user: user) }

      it "returns the active CV" do
        expect(presenter.active_cv).to eq(active_cv)
      end
    end

    context "when user has no active CV" do
      it "returns nil" do
        expect(presenter.active_cv).to be_nil
      end
    end
  end

  describe "#other_cvs" do
    let!(:active_cv) { create(:cv, :active, user: user) }
    let!(:inactive_cv1) { create(:cv, user: user) }
    let!(:inactive_cv2) { create(:cv, user: user) }

    it "returns CVs that are not active" do
      cvs = presenter.other_cvs

      expect(cvs).to include(inactive_cv1, inactive_cv2)
      expect(cvs).not_to include(active_cv)
    end

    it "orders by recent first" do
      older = create(:cv, user: user, created_at: 2.days.ago)
      newer = create(:cv, user: user, created_at: 1.day.ago)

      cvs = presenter.other_cvs
      newer_idx = cvs.find_index { |cv| cv.id == newer.id }
      older_idx = cvs.find_index { |cv| cv.id == older.id }

      expect(newer_idx).to be < older_idx
    end
  end

  describe "#recent_cvs" do
    let!(:older_cv) { create(:cv, user: user, created_at: 2.days.ago) }
    let!(:newer_cv) { create(:cv, user: user, created_at: 1.day.ago) }

    it "returns all CVs ordered by recent first" do
      cvs = presenter.recent_cvs

      expect(cvs).to eq([newer_cv, older_cv])
    end
  end

  describe "#analysis_stream_name" do
    context "with an active CV" do
      let!(:active_cv) { create(:cv, :active, user: user) }

      it "returns the stream name" do
        expect(presenter.analysis_stream_name).to eq("cv_analysis_#{active_cv.id}")
      end
    end

    context "without an active CV" do
      it "returns nil" do
        expect(presenter.analysis_stream_name).to be_nil
      end
    end

    context "with a specific CV" do
      let(:cv) { create(:cv, user: user) }

      it "returns the stream name for that CV" do
        expect(presenter.analysis_stream_name(cv)).to eq("cv_analysis_#{cv.id}")
      end
    end
  end

  describe "#analysis_sections" do
    context "when CV has analysis" do
      let!(:cv) do
        create(
          :cv,
          :active,
          user: user,
          analysis_summary: "Great profile",
          analysis_forces: ["Strong technical skills"],
          analysis_weaknesses: ["Limited leadership"],
          analysis_suggestions: ["Build leadership experience"],
          analyzed_at: Time.current
        )
      end

      it "returns analysis sections" do
        sections = presenter.analysis_sections

        expect(sections[:summary]).to eq("Great profile")
        expect(sections[:strengths]).to include("Strong technical skills")
        expect(sections[:weaknesses]).to include("Limited leadership")
        expect(sections[:suggestions]).to include("Build leadership experience")
      end
    end

    context "when CV has no analysis" do
      let!(:cv) { create(:cv, :active, user: user, analyzed_at: nil) }

      it "returns empty sections" do
        sections = presenter.analysis_sections

        expect(sections).to eq({
          strengths: [],
          weaknesses: [],
          suggestions: [],
          summary: nil
        })
      end
    end

    context "without an active CV" do
      it "returns empty sections" do
        sections = presenter.analysis_sections

        expect(sections).to eq({
          strengths: [],
          weaknesses: [],
          suggestions: [],
          summary: nil
        })
      end
    end
  end
end
```

---

## 6. Python: pytest Basic Setup (CRITICAL)

**File:** `/home/user/job-hunt-agent/python_services/tests/conftest.py`

```python
"""Shared pytest fixtures for job-hunt-agent tests."""
import pytest
from unittest.mock import AsyncMock, MagicMock
from bs4 import BeautifulSoup


@pytest.fixture
def mock_playwright_page():
    """Mock Playwright Page object for browser automation tests."""
    page = AsyncMock()
    page.goto = AsyncMock()
    page.wait_for_load_state = AsyncMock()
    page.evaluate = AsyncMock(return_value="")
    page.query_selector = MagicMock(return_value=None)
    page.query_selector_all = MagicMock(return_value=[])
    page.text_content = AsyncMock(return_value="")
    page.get_attribute = AsyncMock(return_value=None)
    return page


@pytest.fixture
def mock_browser_session():
    """Mock BrowserSession context manager."""
    session = AsyncMock()
    session.__aenter__ = AsyncMock()
    session.__aexit__ = AsyncMock()
    return session


@pytest.fixture
def sample_linkedin_html():
    """Sample LinkedIn job page HTML."""
    return """
    <html>
        <body>
            <h1 class="job-title">Senior Ruby Developer</h1>
            <div class="company-name">TechCorp Inc</div>
            <div class="location">Paris, France</div>
            <div class="job-description">
                We're looking for a talented Ruby developer...
                <ul>
                    <li>5+ years experience</li>
                    <li>Rails expertise</li>
                    <li>PostgreSQL knowledge</li>
                </ul>
            </div>
        </body>
    </html>
    """


@pytest.fixture
def sample_wttj_html():
    """Sample WTTJ job page HTML."""
    return """
    <html>
        <body>
            <h1 data-test="job-title">Backend Engineer</h1>
            <div class="company">StartupXYZ</div>
            <span class="location">Remote</span>
            <section class="job-description">
                Join our growing team...
                Required: Python, FastAPI, PostgreSQL
            </section>
        </body>
    </html>
    """


@pytest.fixture
def mock_faraday_response():
    """Mock Faraday HTTP response."""
    response = MagicMock()
    response.status = 200
    response.body = {
        "title": "Developer",
        "company": "TechCorp",
        "location": "Paris",
        "description": "Job description",
        "platform": "linkedin"
    }
    return response


@pytest.fixture
def mock_faraday_connection():
    """Mock Faraday HTTP connection."""
    conn = MagicMock()
    conn.post = MagicMock()
    conn.get = MagicMock()
    return conn
```

---

## 7. Python: ScraperClient Unit Test Example

**File:** `/home/user/job-hunt-agent/python_services/tests/unit/test_scraper_client.py`

```python
"""Tests for the Scraper API client integration."""
import pytest
from unittest.mock import patch, MagicMock

from scraper_api.main import detect_platform, PARSER_REGISTRY
from scraper_api.core.exceptions import UnsupportedPlatformError


class TestDetectPlatform:
    """Test platform detection from URL."""

    def test_detect_linkedin(self):
        """LinkedIn URLs are detected correctly."""
        url = "https://www.linkedin.com/jobs/view/123456"
        platform = detect_platform(url)
        assert platform == "linkedin"

    def test_detect_linkedin_with_query_params(self):
        """LinkedIn URLs with params are detected."""
        url = "https://www.linkedin.com/jobs/view/123456?foo=bar"
        platform = detect_platform(url)
        assert platform == "linkedin"

    def test_detect_wttj_welcometothejungle(self):
        """WTTJ URLs with welcometothejungle domain are detected."""
        url = "https://www.welcometothejungle.com/jobs/12345"
        platform = detect_platform(url)
        assert platform == "wttj"

    def test_detect_wttj_short_domain(self):
        """WTTJ URLs with short domain are detected."""
        url = "https://jobs.wttj.co/frontend-developer"
        platform = detect_platform(url)
        assert platform == "wttj"

    def test_detect_unsupported_platform(self):
        """Unsupported platforms raise an error."""
        url = "https://www.indeed.com/jobs/view/123"

        with pytest.raises(UnsupportedPlatformError):
            detect_platform(url)

    def test_detect_case_insensitive(self):
        """Platform detection is case-insensitive."""
        url = "https://WWW.LINKEDIN.COM/jobs/view/123"
        platform = detect_platform(url)
        assert platform == "linkedin"


class TestParserRegistry:
    """Test parser registry."""

    def test_linkedin_parser_registered(self):
        """LinkedIn parser is in registry."""
        assert "linkedin" in PARSER_REGISTRY
        from scraper_api.parsers import LinkedinParser
        assert isinstance(PARSER_REGISTRY["linkedin"], LinkedinParser)

    def test_wttj_parser_registered(self):
        """WTTJ parser is in registry."""
        assert "wttj" in PARSER_REGISTRY
        from scraper_api.parsers import WttjParser
        assert isinstance(PARSER_REGISTRY["wttj"], WttjParser)
```

---

## How to Use These Examples

1. Copy the entire code block from the relevant section
2. Create the file at the specified path
3. Run tests:
   ```bash
   # Rails tests
   cd rails_app
   bundle exec rspec spec/services/offer_importers/scraper_client_spec.rb
   
   # Python tests
   cd python_services
   pytest tests/unit/test_scraper_client.py -v
   ```
4. Adjust as needed for your specific setup

---

## Notes

- These examples assume your FactoryBot factories are properly set up
- Mock responses should match your actual API contracts
- Adapt paths and class names if they differ in your project
- All examples follow best practices from the existing test suite
