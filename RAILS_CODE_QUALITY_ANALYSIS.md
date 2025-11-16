# Rails Code Quality Analysis Report

## Executive Summary

The Rails codebase demonstrates **good architectural patterns** with proper use of Services, Presenters, and Form Objects. However, there are **significant code duplication issues**, some **mixing of concerns**, and **opportunities for better error handling**. The application follows Rails conventions well but needs refactoring to reduce duplication.

**Overall Assessment:** 7/10 - Solid foundation with DRY principle violations and room for improvement.

---

## 1. MODELS - Analysis

### Status: GOOD (7.5/10)

#### Strengths:
- Proper use of associations with `dependent: destroy`
- Good enum usage with suffix: true
- JSONB defaults properly handled with `|| []`
- Unique index on active CV enforces data integrity
- Encrypted sensitive fields (OAuth tokens)

#### Issues Found:

##### 1.1 User Model - Weak Validations
**File:** `/home/user/job-hunt-agent/rails_app/app/models/user.rb`

The User model lacks basic validations:
```ruby
# MISSING VALIDATIONS:
# - No presence validation for email (handled by Devise, but not explicit)
# - No validates for has_one/has_many relationships consistency
# - No validate blocks for business logic
```

**Recommendation:** Add explicit validations for clarity:
```ruby
validates :email, presence: true, uniqueness: true  # Already by Devise
validate :google_token_consistency  # If needed
```

##### 1.2 CV Model - Defensive Array Defaults
**File:** `/home/user/job-hunt-agent/rails_app/app/models/cv.rb` (Lines 23-33)

Redundant defensive defaults in model:
```ruby
def analysis_forces
  super || []  # ✗ REDUNDANT - Column already has default: []
end

def analysis_weaknesses
  super || []
end

def analysis_suggestions
  super || []
end
```

The columns already have `default: []` in the schema. These methods are unnecessary.

**Impact:** Minimal - Works correctly but is defensive programming
**Recommendation:** Remove these methods - let the schema handle defaults

##### 1.3 JobOffer Model - Overly Complex Backend Setter
**File:** `/home/user/job-hunt-agent/rails_app/app/models/job_offer.rb` (Lines 36-39)

```ruby
def analysis_backend=(value)
  backend = value.presence&.to_s
  super(ANALYSIS_BACKENDS.fetch(backend, backend))  # Complex chaining
end
```

This setter is confusing - it fetches from a hash but falls back to the original value if not found. Better to use a validator or simpler setter.

**Recommendation:** Simplify or move to a service:
```ruby
validates :analysis_backend, inclusion: { in: ANALYSIS_BACKENDS.values }
# Remove custom setter - use standard assignment
```

---

## 2. CONTROLLERS - Analysis

### Status: GOOD (8/10)

#### Strengths:
- Proper use of before_action filters
- Good separation of concerns with namespaced routes
- Clean RESTful design
- Good use of Form Objects (JobOffers::UrlImportForm, ManualImportForm)
- Proper error handling with custom exceptions
- Presenter pattern reduces view logic

#### Issues Found:

##### 2.1 JobOffersController - Duplicate Backend Logic
**File:** `/home/user/job-hunt-agent/rails_app/app/controllers/job_offers_controller.rb` (Lines 92-97)

```ruby
def resolve_backend(param)
  backend = param.to_s.presence
  return backend if %w[rails python].include?(backend)
  
  ENV.fetch("DEFAULT_OFFER_ANALYSIS_BACKEND", "rails")
end
```

**Issue:** This logic is **duplicated** in `OfferAnalysisJob#normalize_backend` (lines 117-127)

**Impact:** 🔴 **HIGH** - Validation logic split across controller and job
**Risk:** If one is updated, the other will be out of sync

**Recommendation:** Extract to a shared service or constant:
```ruby
# Create: app/services/offer_analyzer_backend.rb
module OfferAnalyzerBackend
  VALID_BACKENDS = %w[rails python].freeze
  DEFAULT = "rails"
  
  def self.normalize(value)
    backend = value.to_s.presence
    return backend if VALID_BACKENDS.include?(backend)
    ENV.fetch("DEFAULT_OFFER_ANALYSIS_BACKEND", DEFAULT)
  end
end
```

##### 2.2 Users::OmniauthCallbacksController - Overly Broad Exception Handling
**File:** `/home/user/job-hunt-agent/rails_app/app/controllers/users/omniauth_callbacks_controller.rb` (Lines 21-23)

```ruby
rescue StandardError => e
  Rails.logger.error("Gmail OAuth error: #{e.class} - #{e.message}")
  redirect_to profile_path, alert: "Erreur lors de la connexion Gmail. Merci de réessayer."
```

**Issue:** Catches all exceptions including `NoMethodError`, `RuntimeError`, etc.

**Impact:** 🟡 **MEDIUM** - Could mask programming errors
**Recommendation:** Be more specific:
```ruby
rescue Signet::AuthorizationError, Google::Apis::AuthorizationError => e
  # Handle auth failures specifically
rescue StandardError => e
  Rails.logger.error("Unexpected error: #{e.class} - #{e.message}")
  # Return generic error
```

##### 2.3 Cvs::OptimizationsController - Inconsistent Error Handling
**File:** `/home/user/job-hunt-agent/rails_app/app/controllers/cvs/optimizations_controller.rb` (Lines 5-6)

```ruby
def new
  redirect_to(cvs_path, alert: "...") and return unless @cv.analysis_available?
  # ^ Using 'and return' instead of guard clause
end
```

While functional, this mixes styles:
- `create` action uses `rescue` blocks
- `new` action uses explicit `return`

**Recommendation:** Use consistent guard clauses:
```ruby
def new
  redirect_to(cvs_path, alert: "Analyse nécessaire...") unless @cv.analysis_available?
end
```

##### 2.4 JobOffersController - Unused Stream Name Variable
**File:** `/home/user/job-hunt-agent/rails_app/app/controllers/job_offers_controller.rb` (Line 88-90)

```ruby
def analysis_stream_name_for(job_offer)
  "job_offer_analysis_#{job_offer.id}"
end
```

This is **never called** from the controller. The stream name is generated in the job. Dead code.

**Recommendation:** Remove this method

---

## 3. SERVICES - Analysis

### Status: ACCEPTABLE (7/10)

#### Strengths:
- Good Service Object pattern implementation
- Custom exception classes for each service
- Proper single responsibility in most services
- Good transaction handling in CvImporters::Create and CvVersions::Activate

#### Critical Issues - Code Duplication:

##### 3.1 JSON Normalization - CRITICAL CODE DUPLICATION
**Files:** 
- `/home/user/job-hunt-agent/rails_app/app/services/ai/cv_analyzer.rb`
- `/home/user/job-hunt-agent/rails_app/app/services/ai/offer_analyzer.rb`

Both files contain **identical** helper methods:
```ruby
# Lines 51-106 in cv_analyzer.rb
# Lines 86-141 in offer_analyzer.rb

def normalize_payload(raw)        # DUPLICATED
def normalize_array(value)        # DUPLICATED
def strip_code_fences(text)       # DUPLICATED
def extract_json_fragment(text)   # DUPLICATED
def unwrap_payload(raw)           # DUPLICATED
def build_analysis_hash(hash)     # Similar pattern but field names differ
```

**Impact:** 🔴 **CRITICAL**
- 60+ lines of duplicated code
- If bug found in JSON parsing, must fix in 2 places
- Maintenance nightmare

**Recommendation:** Extract to shared module:
```ruby
# app/services/ai/shared_json_normalizer.rb
module Ai
  module SharedJsonNormalizer
    # ... all the shared methods
  end
end

# Then in both analyzers:
class CvAnalyzer
  include SharedJsonNormalizer
  
  def build_analysis_hash(hash)
    super.tap do |attrs|
      attrs[:strengths] = normalize_array(attrs[:strengths])
      # ... CV-specific fields
    end
  end
end
```

##### 3.2 Ai::Client - Overly Defensive Initialization
**File:** `/home/user/job-hunt-agent/rails_app/app/services/ai/client.rb`

```ruby
def initialize(model: default_model, provider: configured_provider)
  @model = model
  @provider = provider
end

def chat
  chat = RubyLLM.chat
  chat = chat.with_model(model, provider: provider.presence) if model.present? || provider.present?
  # ^ Conditional chain is confusing
  chat
rescue RubyLLM::Error => e
  raise Error, e.message
end
```

**Issue:** Method reuses `model` and `provider` as variable names, confusing to read.

**Recommendation:** Clarify:
```ruby
def chat
  base_chat = RubyLLM.chat
  
  return base_chat if @model.blank? && @provider.blank?
  
  base_chat.with_model(@model, provider: @provider.presence)
rescue RubyLLM::Error => e
  raise Error, e.message
end
```

##### 3.3 Ai::OfferAnalyzer - Complex Initialization
**File:** `/home/user/job-hunt-agent/rails_app/app/services/ai/offer_analyzer.rb` (Lines 9-14)

```ruby
def initialize(
  job_offer:, 
  streamer: nil, 
  client: Ai::Client.new,      # Default creates new instance
  backend: :rails, 
  agent_connection: nil         # Optional dependency
)
  @job_offer = job_offer
  @streamer = streamer
  @client = client
  @backend = normalize_backend(backend)
  @agent_connection = agent_connection
end
```

Multiple optional dependencies make testing complex.

**Recommendation:** Use explicit dependency injection or ServiceLocator pattern in tests

##### 3.4 OfferImporters::ScraperClient - Lazy Connection Initialization
**File:** `/home/user/job-hunt-agent/rails_app/app/services/offer_importers/scraper_client.rb` (Lines 28-33)

```ruby
def connection
  @connection ||= Faraday.new(url: base_url) do |faraday|
    faraday.response :raise_error
    faraday.adapter Faraday.default_adapter
  end
end
```

Good pattern for lazy initialization, but:
- If `base_url` changes after first call, connection won't update
- Consider if connection is truly immutable

**Status:** OK for this use case (base_url is environment variable)

##### 3.5 CvVersions::CreateFromAnalysis - Over-delegation
**File:** `/home/user/job-hunt-agent/rails_app/app/services/cv_versions/create_from_analysis.rb`

```ruby
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
```

**Issue:** This is basically a wrapper around `CvImporters::Create`. Only 2 lines of logic added.

**Recommendation:** Consider if this service is necessary - could use Create directly with a conditional

---

## 4. JOBS - Analysis

### Status: NEEDS IMPROVEMENT (6.5/10)

#### Issues Found:

##### 4.1 Mixing of Concerns - ActionView::RecordIdentifier in Jobs
**Files:**
- `/home/user/job-hunt-agent/rails_app/app/jobs/cv_analysis_job.rb` (Line 6)
- `/home/user/job-hunt-agent/rails_app/app/jobs/offer_analysis_job.rb` (Line 6)

```ruby
class CvAnalysisJob < ApplicationJob
  include ActionView::RecordIdentifier  # ✗ BAD: Couples jobs to view layer
```

**Issue:** 
- Jobs shouldn't know about views
- `dom_id` is a view helper
- Makes jobs harder to test in isolation
- Violates separation of concerns

**Impact:** 🟡 **MEDIUM** - Not wrong, but architecturally loose

**Recommendation:** Extract to a helper class:
```ruby
# app/services/turbo_stream_helpers.rb
module TurboStreamHelpers
  extend self
  
  def analysis_stream_name(object)
    "#{object.class.name.downcase}_analysis_#{object.id}"
  end
  
  def dom_id_for_analysis(object)
    "#{object.model_name.singular}_#{object.id}_analysis"
  end
end

# In jobs:
class CvAnalysisJob < ApplicationJob
  def broadcast_panel(cv)
    # ... use TurboStreamHelpers instead
  end
end
```

##### 4.2 Duplicated JSON Extraction Logic
**Files:**
- `/home/user/job-hunt-agent/rails_app/app/jobs/cv_analysis_job.rb` (Lines 68-91)
- `/home/user/job-hunt-agent/rails_app/app/jobs/offer_analysis_job.rb` (Lines 73-96)

Both jobs have identical methods:
```ruby
def extract_analysis(buffer)         # DUPLICATED
def capture_json_segment(buffer)     # DUPLICATED
def sanitized_stream(buffer, ...)    # DUPLICATED
def normalize_analysis_hash(parsed)  # DUPLICATED (with different field names)
```

**Impact:** 🔴 **HIGH** - 50+ lines of duplicated code
**Recommendation:** Extract to shared service or concern

##### 4.3 OfferAnalysisJob - Duplicate Backend Normalization
**File:** `/home/user/job-hunt-agent/rails_app/app/jobs/offer_analysis_job.rb` (Lines 117-127)

```ruby
def normalize_backend(mode)
  key = mode.to_s.presence
  key = default_backend unless SUPPORTED_BACKENDS.include?(key)
  key = default_backend unless SUPPORTED_BACKENDS.include?(key)  # ✗ DUPLICATE LINE!
  key.to_sym
end
```

**Issue:** Line 120 is identical to line 119 (copy-paste error)

**Impact:** 🔴 **BUG** - Not a functional bug, but clearly a copy-paste error

**Recommendation:** Fix immediately:
```ruby
def normalize_backend(mode)
  key = mode.to_s.presence || default_backend
  return key.to_sym if SUPPORTED_BACKENDS.include?(key)
  default_backend.to_sym
end
```

##### 4.4 Job Stream Broadcasting - Complex Logic in Jobs
**Files:** Both analysis jobs (Lines 26-49 and 29-49)

The jobs contain complex Turbo Streams broadcasting logic mixed with analysis execution:
```ruby
def perform(cv_id)
  @cv = Cv.find(cv_id)
  @stream_buffer = +""
  
  Ai::CvAnalyzer.new(cv: @cv, streamer: ->(chunk) { handle_stream(chunk) }).call
  @cv.reload
  
  broadcast_panel(@cv)
rescue Ai::CvAnalyzer::Error => e
  broadcast_error(@cv, e.message)
end
```

**Issue:** Jobs have streaming logic responsibility

**Better approach:** Use Turbo Streams Broadcasting as a service concern

---

## 5. FORM OBJECTS - Analysis

### Status: GOOD (8.5/10)

#### Strengths:
- Both forms properly inherit from ActiveModel::Model
- Good validation setup
- Form objects handle service orchestration (submit pattern)
- Error handling wraps service errors

#### Minor Issues:

##### 5.1 ManualImportForm - Tech Stack Parsing Logic
**File:** `/home/user/job-hunt-agent/rails_app/app/forms/job_offers/manual_import_form.rb` (Lines 47-55)

```ruby
def parse_tech_stack
  return [] if tech_stack_input.blank?

  tech_stack_input
    .split(/[,;\n]/)
    .map(&:strip)
    .reject(&:blank?)
end
```

**Issue:** This is pure parsing logic that could be shared or tested independently

**Recommendation:** Could be extracted to a small service if reused elsewhere

---

## 6. PRESENTERS - Analysis

### Status: GOOD (8/10)

#### Strengths:
- Clean separation of view logic from models
- Well-structured with clear responsibilities
- Good use of constants (SOURCE_LABELS, BACKEND_OPTIONS)
- Defensive programming with safe navigation

#### Minor Observations:

##### 6.1 JobOfferPresenter - Defensive Nil Handling
**File:** `/home/user/job-hunt-agent/rails_app/app/presenters/job_offer_presenter.rb` (Lines 79-82)

```ruby
def option_for(mode)
  key = mode.to_s.presence
  BACKEND_OPTIONS.fetch(key, nil) || { label: "Flux non défini", badge_classes: "bg-slate-200 text-slate-600" }
end
```

**Issue:** Could use `fetch` with default directly:
```ruby
def option_for(mode)
  key = mode.to_s.presence
  BACKEND_OPTIONS.fetch(
    key,
    { label: "Flux non défini", badge_classes: "bg-slate-200 text-slate-600" }
  )
end
```

---

## Summary of Issues by Severity

### 🔴 CRITICAL (Must Fix)
1. **Code Duplication in Services** - `normalize_payload`, `extract_json_fragment`, etc. in both analyzers
2. **Duplicate Backend Validation** - Controller vs Job - can diverge
3. **Copy-Paste Error** - OfferAnalysisJob line 119-120 duplicate

### 🟡 MEDIUM (Should Fix)
1. Overly broad exception handling (OmniauthCallbacksController)
2. Mixing of concerns (ActionView in Jobs)
3. Inconsistent error handling styles across controllers
4. Optional dependencies in service initialization

### 🟢 LOW (Nice to Have)
1. Remove redundant CV model methods
2. Simplify JobOffer backend setter
3. Remove dead controller methods
4. Clarify confusing variable names

---

## Recommendations for Refactoring

### Phase 1 - High Priority
1. Extract shared JSON normalization to `Ai::JsonNormalizer` module
2. Create `OfferAnalyzerBackend` service to centralize backend logic
3. Fix copy-paste error in OfferAnalysisJob
4. Extract Turbo Streams concern from jobs

### Phase 2 - Medium Priority
1. Extract job JSON extraction to shared service
2. Improve exception handling specificity
3. Make error handling consistent across controllers

### Phase 3 - Low Priority
1. Remove redundant CV model defensive methods
2. Simplify JobOffer backend setter
3. Minor variable name clarifications

---

## Testing Observations

**No test files were analyzed in detail, but:**
- Service architecture enables good testability
- Form objects are easily testable
- Jobs will be easier to test once concerns are separated
- Consider adding specs for the duplicated logic to catch regressions

