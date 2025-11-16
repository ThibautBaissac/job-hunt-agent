# Test Coverage Fix Priorities

## Immediate Actions (This Week)

### 1. Set Up Python Testing Infrastructure

**Status:** CRITICAL - 0% test coverage

Create the following structure:

```bash
python_services/
├── tests/
│   ├── __init__.py
│   ├── conftest.py          # Pytest fixtures and configuration
│   ├── unit/
│   │   ├── test_scraper_api.py
│   │   ├── test_agent_api.py
│   │   ├── test_parsers.py
│   │   └── test_schemas.py
│   └── integration/
│       └── test_api_endpoints.py
├── pytest.ini               # Pytest configuration
└── pyproject.toml           # Updated with pytest config
```

**Files to Create:**

**a) `python_services/pytest.ini`**
```ini
[pytest]
pythonpath = .
asyncio_mode = auto
markers =
    unit: Unit tests
    integration: Integration tests
    slow: Slow tests
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
```

**b) `python_services/tests/conftest.py`**
```python
import pytest
from unittest.mock import AsyncMock, MagicMock


@pytest.fixture
def mock_playwright_page():
    """Mock Playwright Page object."""
    page = AsyncMock()
    page.goto = AsyncMock()
    page.wait_for_load_state = AsyncMock()
    page.evaluate = AsyncMock()
    page.query_selector = MagicMock()
    return page


@pytest.fixture
def mock_faraday_connection():
    """Mock Faraday HTTP connection."""
    conn = MagicMock()
    conn.post = MagicMock()
    return conn
```

### 2. Test ScraperClient (Critical)

**Location:** `rails_app/spec/services/offer_importers/scraper_client_spec.rb`

**Priority:** HIGH - This is the only HTTP client in the rails app not tested

**Test Cases:**
- ✅ Successful response parsing
- ✅ Invalid JSON handling
- ✅ Missing fields handling
- ✅ Faraday timeout errors
- ✅ Faraday connection errors
- ✅ Network error wrapping
- ✅ Valid URL parsing

**Effort:** 1-2 hours

### 3. Test TextExtractor (Critical)

**Location:** `rails_app/spec/services/cv_importers/text_extractor_spec.rb`

**Priority:** HIGH - PDF/DOCX parsing can fail silently

**Test Cases:**
- ✅ PDF file extraction
- ✅ DOCX file extraction
- ✅ Unsupported file type
- ✅ Empty file handling
- ✅ Corrupt file handling
- ✅ Large file handling
- ✅ Text encoding edge cases

**Effort:** 2-3 hours

### 4. Test CvAnalysisJob

**Location:** `rails_app/spec/jobs/cv_analysis_job_spec.rb`

**Priority:** HIGH - Background job is untested

**Test Cases:**
- ✅ Job enqueueing
- ✅ Analysis execution
- ✅ Streaming callback invocation
- ✅ Result persistence
- ✅ Error broadcast
- ✅ Job idempotency

**Effort:** 1-2 hours

---

## High Priority (Next Sprint)

### 1. Python Service Tests

**Total Effort:** 2-3 days

#### A. Agent API Tests
- `test_agent_api/test_main.py` - Health endpoints
- `test_agent_api/test_offer_analysis.py` - Offer analysis endpoint
- `test_agent_api/test_schemas.py` - Request/response validation

#### B. Scraper API Tests
- `test_scraper_api/test_main.py` - Health, platform detection
- `test_scraper_api/test_parsers.py` - BaseParser, LinkedIn, WTTJ
- `test_scraper_api/test_browser.py` - BrowserConfig, BrowserSession
- `test_scraper_api/test_schemas.py` - Request/response validation

**Mock Data Needed:**
- Sample HTML for LinkedIn job page
- Sample HTML for WTTJ job page
- Mock Faraday responses
- Mock Playwright browser

### 2. Form Tests

**Location:** `rails_app/spec/forms/`

**Priority:** MEDIUM

#### A. ManualImportForm
`rails_app/spec/forms/job_offers/manual_import_form_spec.rb`
- ✅ Valid submission
- ✅ Missing required fields
- ✅ Invalid URL format
- ✅ Tech stack parsing (comma, semicolon, newline separated)
- ✅ Job enqueuing

#### B. UrlImportForm  
`rails_app/spec/forms/job_offers/url_import_form_spec.rb`
- ✅ Valid submission
- ✅ Invalid URL
- ✅ Scraper error handling
- ✅ Job offer creation

**Effort:** 3-4 hours

### 3. Presenter Tests

**Location:** `rails_app/spec/presenters/`

#### A. CvPresenter
`rails_app/spec/presenters/cv_presenter_spec.rb`
- ✅ active_cv returns correct CV
- ✅ other_cvs excludes active CV
- ✅ recent_cvs ordering
- ✅ analysis_stream_name generation
- ✅ analysis_sections with/without data

#### B. JobOfferPresenter
`rails_app/spec/presenters/job_offer_presenter_spec.rb`
- ✅ Display formatting
- ✅ Tech stack display
- ✅ Analysis availability
- ✅ Seniority level display

**Effort:** 2-3 hours

### 4. System Tests

**Location:** `rails_app/spec/system/` (new directory)

**Priority:** MEDIUM

#### A. CV Upload Flow
```ruby
feature "CV Upload and Analysis" do
  scenario "User uploads CV and analyzes it" do
    # 1. Sign in
    # 2. Upload CV file
    # 3. Verify CV appears
    # 4. Click analyze
    # 5. Verify analysis appears
  end
end
```

#### B. Job Offer Import Flow
```ruby
feature "Job Offer Import" do
  scenario "User imports job from URL" do
    # 1. Sign in
    # 2. Enter job URL
    # 3. Verify job appears
    # 4. Verify analysis queued
  end
  
  scenario "User manually creates job" do
    # 1. Sign in
    # 2. Fill manual form
    # 3. Verify job appears
  end
end
```

**Effort:** 2-3 days (requires browser automation setup)

---

## Medium Priority (Following Sprints)

### 1. Coverage Threshold Enforcement

**Add to CI:**
```yaml
# In Gemfile under test group
gem "simplecov", require: false
gem "simplecov-json", require: false

# Configure in spec_helper.rb
SimpleCov.minimum_coverage 80
SimpleCov.minimum_coverage_by_file 70
```

**Effort:** 2 hours

### 2. Contract Tests

**Location:** `rails_app/spec/contracts/`

Test API contracts between:
- Rails ↔ Agent API
- Rails ↔ Scraper API

**Effort:** 1 day

### 3. Model Completeness

Expand model tests:
- Profile: Add validation tests, nested associations
- Cv: Add analysis persistence, attachment tests
- JobOffer: Add enum edge cases, state transitions

**Effort:** 4-6 hours

---

## Test Coverage by File (Rails)

### Currently Missing Tests (19 files untested/undertested)

**Critical (5):**
1. `app/services/offer_importers/scraper_client.rb`
2. `app/services/cv_importers/text_extractor.rb`
3. `app/services/ai/client.rb`
4. `app/jobs/cv_analysis_job.rb`
5. `app/forms/job_offers/manual_import_form.rb`

**High (6):**
6. `app/presenters/cv_presenter.rb`
7. `app/presenters/job_offer_presenter.rb`
8. `app/services/cv_versions/create_from_analysis.rb` (partial)
9. `app/services/integrations/gmail_client.rb` (partial)
10. `app/controllers/cvs/optimizations_controller.rb` (partial)
11. `app/controllers/application_controller.rb`

**Medium (8):**
12. All views (no system tests)
13. `app/models/profile.rb` (validations only)
14. `app/models/cv.rb` (attachments)
15. `app/models/job_offer.rb` (edge cases)
16. `app/helpers/application_helper.rb`
17. `app/mailers/application_mailer.rb`
18. `app/jobs/application_job.rb`
19. Multiple form classes

---

## Python Test Coverage Summary

### Critical (Must test)
- [x] API endpoints (health checks, offer analysis router, scrape endpoint)
- [x] BaseParser class (load, extract, validate, helper methods)
- [x] Platform parsers (LinkedIn, WTTJ)
- [x] Schema validation (Pydantic models)
- [x] Error handling (all exception types)
- [x] Browser configuration and session

### High (Should test)
- [x] LangChain integration
- [x] Mock Claude API responses
- [x] HTML parsing utilities
- [x] Config parsing from environment

### Medium (Nice to test)
- [ ] Performance (large files, slow networks)
- [ ] Concurrency (multiple concurrent scrapes)
- [ ] Caching behavior

---

## Quick Fix Checklist

### This Week
- [ ] Create Python test directory structure
- [ ] Create pytest.ini and conftest.py
- [ ] Test ScraperClient (1-2 hours)
- [ ] Test TextExtractor (2-3 hours)
- [ ] Test CvAnalysisJob (1-2 hours)

### Next Sprint
- [ ] Python service tests (Agent API)
- [ ] Python service tests (Scraper API)
- [ ] Form tests (ManualImportForm, UrlImportForm)
- [ ] Presenter tests

### Following Sprint
- [ ] System tests (UI workflows)
- [ ] Coverage threshold enforcement
- [ ] Contract tests

---

## Files Created So Far

✅ `/home/user/job-hunt-agent/TEST_COVERAGE_ANALYSIS.md` - Complete analysis report
✅ `/home/user/job-hunt-agent/TEST_PRIORITIES.md` - This file

## Next Documents to Create

- [ ] `TESTING_GUIDE.md` - How to write tests in this project
- [ ] Example Python test file
- [ ] Example Rails test file  
- [ ] CI/CD configuration for tests
- [ ] Coverage badges/reports configuration
