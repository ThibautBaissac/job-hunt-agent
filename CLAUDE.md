# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **monorepo** containing an AI-powered job application automation platform:

- **Rails App** (`rails_app/`): Rails 8.1 UI and business logic layer
- **Agent API** (`python_services/agent_api/`): FastAPI service for AI orchestration using LangChain + Anthropic Claude (port 8001)
- **Scraper API** (`python_services/scraper_api/`): FastAPI service for job offer web scraping using Playwright (port 8002)

**Tech Stack:**
- Rails: Hotwire (Turbo + Stimulus), Tailwind CSS, Devise auth, ActiveStorage, Solid Queue
- Python: FastAPI, LangChain, Playwright, BeautifulSoup, Pydantic
- Database: PostgreSQL (multi-database: primary, queue, cache, cable)

## Development Commands

### Starting Services

```bash
# Start all services (Rails + Agent API + Scraper API)
bin/dev                              # From project root

# Rails-specific
cd rails_app
bin/setup                            # Initial setup (deps, DB creation)
bin/rails server                     # Rails only (port 5000)
bin/rails console                    # Interactive console
bin/jobs                             # Process background jobs (Solid Queue)

# Python services (after activating venv)
source python_services/api/.venv/bin/activate
uvicorn python_services.agent_api.main:app --reload --port 8001
uvicorn python_services.scraper_api.main:app --reload --port 8002
```

### Testing

```bash
# Rails - Run all tests
cd rails_app
bin/rails test                       # Unit/integration tests
bin/rails test:system                # Browser-based system tests
bundle exec rspec                    # RSpec suite

# Rails - Single test file
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/models/user_spec.rb:42  # Specific line

# Python - All tests
source python_services/api/.venv/bin/activate
pytest python_services/              # All services
pytest python_services/scraper_api/  # Specific service
pytest -v --cov                      # Verbose with coverage
```

### Code Quality

```bash
# Rails - Full CI pipeline (runs everything)
cd rails_app
bin/ci                               # Rubocop + security scans + tests + seed

# Rails - Individual tools
bin/rubocop                          # Linter (Rails Omakase style)
bin/brakeman                         # Security scanner
bin/bundler-audit                    # Gem vulnerability check
bin/importmap audit                  # JS dependency check

# Python - Linting and formatting
source python_services/api/.venv/bin/activate
black python_services/               # Auto-format
ruff check python_services/          # Lint
mypy python_services/                # Type checking
```

### Database

```bash
cd rails_app
bin/rails db:migrate                 # Run migrations
bin/rails db:reset                   # Drop, create, migrate, seed
bin/rails db:seed                    # Load seed data
```

### Python Environment Setup

```bash
cd python_services/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
playwright install                   # Install browser binaries
```

## Architecture & Structure

### Service Communication Flow

```
User → Rails UI → HTTP/JSON → Python Services (Agent API + Scraper API)
         ↓
   PostgreSQL (Multi-DB)
         ↓
   Solid Queue (Background Jobs)
```

- Rails communicates with Python services via HTTP using Faraday clients
- Base URLs configured via environment variables: `AGENT_API_URL`, `SCRAPER_API_URL`
- Async operations handled via Solid Queue background jobs

### Core Data Models

**User** (Authentication & Ownership)
- `has_one :profile`
- `has_many :cvs` (one active CV via unique index)
- `has_many :job_offers`
- OAuth integration with Google (encrypted tokens for Gmail API)

**Profile** (Professional Information)
- `belongs_to :user`
- Fields: name, title, location, GitHub/LinkedIn URLs
- AI preferences: `ai_language` (fr/en), `ai_tone` (neutral/professional/direct)
- Default email signature

**Cv** (Resume Management with Versioning)
- `belongs_to :user`
- `has_one_attached :document` (ActiveStorage for PDF/DOCX)
- Import methods: paste text or upload document
- AI analysis fields (JSONB): summary, strengths, weaknesses, suggestions
- Active CV enforcement via unique index on `user_id` where `is_active = true`

**JobOffer** (Job Postings)
- `belongs_to :user`
- Source tracking: `linkedin`, `wttj`, `other` (enum)
- Fields: title, company, location, description, `tech_stack` (JSONB array)
- AI analysis: summary, analyzed_at timestamp
- Application tracking: status (enum for Kanban workflow), applied_at, response_at

### Service Layer Architecture

Rails follows **Service Object Pattern** with namespaced POROs (not in models/controllers):

- **`OfferImporters::`** - Job offer import orchestration
  - `CreateFromUrl`: Coordinates with ScraperClient, triggers OfferAnalysisJob
  - `ScraperClient`: HTTP client wrapper for scraper_api

- **`Ai::`** - AI service integrations
  - `Client`: Wrapper around ruby_llm gem (Anthropic Claude)
  - `CvAnalyzer`: Analyzes CV with structured schema validation
  - `OfferAnalyzer`: Future job offer analysis
  - `Schemas::CvAnalysisSchema`: Schema validation for AI responses

- **`CvImporters::`** - CV document processing
  - `TextExtractor`: Extracts text from PDF/DOCX files
  - `Create`: Orchestrates CV creation from paste or upload

- **`CvVersions::`** - CV version management
  - `Activate`: Manages active CV switching with validation
  - `CreateFromAnalysis`: Creates optimized CV versions from AI suggestions

- **`Integrations::`** - External service clients
  - `GmailClient`: OAuth-based Gmail API integration (send-only scope)

Each service has **single responsibility** and handles its own error cases.

### Background Jobs (Solid Queue)

- `CvAnalysisJob`: Async CV analysis via AI (long-running)
- `OfferAnalysisJob`: Async job offer analysis
- Jobs queued after user actions for better UX (no waiting for AI responses)
- Processed by `bin/jobs` worker

### Python Services Architecture

**Agent API** (port 8001) - AI Orchestration
- Health check: `GET /health`
- Uses LangChain for prompt engineering and chain orchestration
- Communicates with Anthropic Claude API
- Future endpoints: `/agent/job_application`, `/agent/cv_analysis`

**Scraper API** (port 8002) - Web Scraping
- Health check: `GET /health`
- Endpoint: `POST /scrape/offer` - Extracts job data from URL
- **Parser Registry Pattern**: Extensible platform detection (LinkedIn, WTTJ)
  - Base parser: `parsers/base.py` with `BaseParser` ABC
  - Platform parsers: `parsers/linkedin.py`, `parsers/wttj.py`
  - Registry auto-discovers parsers in `parsers/__init__.py`
  - Add new platforms by implementing `BaseParser` and registering
- Playwright browser automation with configurable options
- Environment vars: `SCRAPER_HEADLESS`, `SCRAPER_PAGE_TIMEOUT_MS`, `SCRAPER_USER_AGENT`, `SCRAPER_LAUNCH_ARGS`

### Database Architecture

Rails uses **multiple databases** (Rails 8 feature):
- **Primary DB**: User data, CVs, job offers (schema: `db/schema.rb`)
- **Solid Queue DB**: Background job queuing (`db/queue_schema.rb`)
- **Solid Cache DB**: Application-level caching (`db/cache_schema.rb`)
- **Solid Cable DB**: WebSocket connections (`db/cable_schema.rb`)

Migrations run separately for each database. All schemas are tracked in version control.

### Frontend Architecture

- **Hotwire Stack**: Turbo Frames/Streams + Stimulus controllers (no webpack)
- **Importmap**: ES modules imported directly in browser
- **Tailwind CSS**: Utility-first styling
- Stimulus controllers: `/app/javascript/controllers`
- Views follow Rails conventions with partials in `/app/views/shared`

## Key Patterns & Conventions

### Service Object Pattern
- Business logic extracted into service classes (not models/controllers)
- Namespaced by domain (`Ai::`, `OfferImporters::`, etc.)
- Single Responsibility Principle (SRP) enforced
- Error handling via custom exception classes

### Presenter Pattern
- `CvPresenter`, `JobOfferPresenter` in `/app/presenters`
- View logic extracted from templates for cleanliness and testability

### Form Objects Pattern
- Complex forms in `/app/forms` directory
- Separate from ActiveRecord models
- Handle multi-step or composite form logic

### Parser Registry Pattern (Python)
- New job platforms added by implementing `BaseParser`
- Auto-discovery via registry in `parsers/__init__.py`
- Platform detection via `can_parse(url)` method

### Testing Conventions
- **RSpec**: Type inference from file location (`spec/models/`, `spec/requests/`, etc.)
- **FactoryBot**: Test data generation (factories in `spec/factories/`)
- **Request specs**: For testing API-like controller actions
- **Shoulda-Matchers**: For concise model validation tests
- **SimpleCov**: Coverage tracking (auto-generated reports)
- **Python**: pytest with async support, Pydantic for schema validation

### Rails Conventions
- RESTful routes with custom member/collection actions
- Devise for authentication with OmniAuth callbacks (`/users/auth/google_oauth2/callback`)
- ActiveStorage for file uploads (stored in `storage/` directory)
- JSONB columns for flexible data (`tech_stack`, AI analysis results)
- Encrypted attributes for sensitive data (OAuth tokens via `encrypts` macro)

### Code Style
- **Rails**: Rubocop Rails Omakase (Basecamp's official style guide)
- **Python**: Ruff linter + Black formatter (100 char line length), mypy for type checking

## Important Context

### Environment Variables

Required in root `.env` file (not committed):

```bash
# Python Service URLs
AGENT_API_URL=http://localhost:8001
SCRAPER_API_URL=http://localhost:8002

# AI Services
ANTHROPIC_API_KEY=sk-ant-...

# Google OAuth (for Gmail integration)
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

# Optional: Scraper configuration
SCRAPER_HEADLESS=true
SCRAPER_PAGE_TIMEOUT_MS=30000
```

### Application Workflow (Kanban States)

Job offers follow a state machine workflow:
- `to_process` → `preparing` → `sent` → `interview` → `offer`/`rejected`/`no_answer`

States drive UI Kanban columns. Timestamps tracked for each transition.

### Known Limitations

- **Playwright in Dev Container**: Chromium crashes due to resource constraints
  - Workaround: Use manual job offer entry fallback
  - Future: API-based scraping or external deployment

- **Gmail OAuth**: Requires Google Cloud project setup with OAuth consent screen
  - Scopes limited to `gmail.send` (send-only for security)

### Security Measures

- `bin/brakeman`: Security vulnerability scanning
- `bin/bundler-audit`: Gem dependency vulnerability checks
- Encrypted credentials: OAuth tokens use Rails encryption
- CSRF protection: `omniauth-rails_csrf_protection` gem
- Input validation: Strong parameters in controllers, Pydantic schemas in Python

### Extensibility Points

1. **New Job Platforms**: Implement `BaseParser` in `python_services/scraper_api/parsers/`
2. **New AI Services**: Add to `Ai::` namespace following existing patterns
3. **Background Jobs**: Create in `app/jobs/` inheriting from `ApplicationJob`
4. **Service Clients**: Add to `app/services/integrations/` for external APIs

### Documentation

Additional context in:
- `README.md`: Setup, deployment, troubleshooting
- `.github/copilot-instructions.md`: Development guidelines and conventions
- `docs/architecture*.md`: Detailed architecture diagrams and contracts
- `docs/backlog.md`: Product roadmap and user stories (French)
