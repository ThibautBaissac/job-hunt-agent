# Job Hunt Agent

An intelligent job application automation platform that combines Rails UI/business logic with Python microservices for job scraping and AI-powered application matching.

## 📋 Project Structure

```
job-hunt-agent/
├── rails_app/              # Rails 8.1 application (UI & business logic)
├── python_services/        # Python microservices
│   ├── agent_api/         # FastAPI service for job matching & content generation
│   ├── scraper_api/       # FastAPI service for web scraping
│   └── api/               # Shared Python environment
├── docs/                   # Project documentation
└── bin/
    ├── dev                # Start all services
    └── ci                 # Run all tests & linters
```

## 🚀 Quick Start

### Option 1: Dev Container (Recommended)

The easiest way to get started is using VS Code Dev Containers, which automatically handles all setup.

**Prerequisites:**
- **VS Code** with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- **Docker** installed and running

**Setup Steps:**

1. **Clone and open in container:**
   ```bash
   git clone <repo-url>
   cd job-hunt-agent
   code .
   ```

2. **Open in Dev Container:**
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Type "Dev Containers: Reopen in Container"
   - Wait for the container to build (first time takes ~5 minutes)

3. **Services start automatically** - The dev container runs the postCreateCommand which:
   - Installs Ruby gems
   - Prepares PostgreSQL
   - Sets up Python virtual environment
   - Installs Playwright and system dependencies
   - Installs foreman

4. **Start development services:**
   ```bash
   bin/dev
   ```

That's it! All services are running:
- **Rails**: http://localhost:5000
- **Agent API**: http://localhost:8001
- **Scraper API**: http://localhost:8002

### Option 2: Local Setup (Advanced)

If you prefer to run services locally without Docker:

**Prerequisites:**
- **Ruby** 3.3.6+ (managed by `mise` or `rbenv`)
- **Python** 3.11+
- **PostgreSQL** 15+
- **Git**

**Setup Steps:**

```bash
# Clone the repository
git clone <repo-url>
cd job-hunt-agent

# Setup Rails (creates databases, installs dependencies)
cd rails_app && bin/setup --skip-server

# You're ready!
cd ..
bin/dev
```

This will:
- ✅ Start PostgreSQL (if not already running)
- ✅ Install Ruby gems
- ✅ Install foreman
- ✅ Create and prepare Rails databases
- ✅ Set up Python virtual environment
- ✅ Install Python dependencies
- ✅ Install Playwright browsers

### Start Development Services

```bash
# From project root, start all services
bin/dev
```

This starts:
- **Rails app** on `http://localhost:5000`
- **Agent API** on `http://localhost:8001` (FastAPI with auto-reload)
- **Scraper API** on `http://localhost:8002` (FastAPI with auto-reload)

All services log to the terminal and will auto-reload when you make changes.

## 🛠️ Development Workflow

### Common Rails Tasks

```bash
cd rails_app

# Open Rails console
bin/rails console

# Run migrations
bin/rails db:migrate

# Create sample data
bin/rails db:seed

# Run tests
bin/rails test                    # Unit & integration tests
bin/rails test:system             # System tests (browser)

# Code quality checks
bin/rubocop
bin/brakeman
bundle audit
```

### Common Python Tasks

```bash
# Activate Python environment
source python_services/api/.venv/bin/activate

# Run tests
pytest python_services/

# Format code
black python_services/

# Lint code
ruff check python_services/

# Type checking
mypy python_services/
```

### Full CI Pipeline

```bash
cd rails_app && bin/ci
```

Runs:
- Rubocop (Ruby linter)
- Bundler audit
- Brakeman (security scanner)
- Rails tests
- System tests
- Database seed verification

## 🏗️ Architecture

### Rails Application (`rails_app/`)
- **Framework:** Rails 8.1 with importmap, Turbo, and Stimulus
- **Database:** PostgreSQL with Solid Queue for background jobs
- **Key Features:**
  - User/profile management
  - Job offer tracking
  - Application workflow (to_process → preparing → sent → interview → offer/rejected/no_answer)
  - AI-powered job matching
  - Email integration with Gmail

### Agent API (`python_services/agent_api/`)
**FastAPI service** running on port 8001
- **Purpose:** AI-powered job analysis and content generation
- **Tech Stack:** LangChain, Anthropic Claude, FastAPI
- **Input:** `{ job_offer: {...}, cv: {...}, profile: {...}, template: {...} }`
- **Output:** `{ summary, match_score, email_subject, email_body, cover_letter, cv_suggestions }`

### Scraper API (`python_services/scraper_api/`)
**FastAPI service** running on port 8002
- **Purpose:** Extract job postings from various job boards
- **Tech Stack:** Playwright, BeautifulSoup, FastAPI
- **Input:** `{ url: "..." }`
- **Output:** `{ title, company, location, description, platform }`

### Shared Python Environment
Located in `python_services/api/.venv/`, contains:
- **FastAPI 0.115+** - Web framework
- **Pydantic 2.10+** - Data validation
- **LangChain 0.3+** - AI orchestration
- **Playwright 1.48+** - Browser automation
- **Development tools:** pytest, black, ruff, mypy

## 🔐 Environment Variables

Create a `.env` file in the project root:

```env
# API Keys
ANTHROPIC_API_KEY=sk-ant-...

# Service URLs
AGENT_API_URL=http://localhost:8001
SCRAPER_API_URL=http://localhost:8002

# Gmail integration (optional)
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

# Database (optional, uses defaults in dev)
DB_HOST=localhost
DB_USER=postgres
DB_PASSWORD=postgres

# Rails
# Rails
RAILS_ENV=development
```

## 🔑 Gmail OAuth Setup

Complete these steps in the Google Cloud Console before connecting Gmail from the app:

### Detailed Google Cloud Setup Steps

1. **Go to OAuth consent screen:**
   - Google Cloud Console → *APIs & Services* → **OAuth consent screen**

2. **Configure Audience (User Type: External):**
   - Choose *External* as the user type (for personal/testing use)

3. **Add or Configure Scopes:**
   - In the OAuth consent screen, go to *Scopes* section
   - Click **Add or Remove Scopes** and add the following:
     - `https://www.googleapis.com/auth/userinfo.email` (basic profile info)
     - `https://www.googleapis.com/auth/userinfo.profile` (basic profile info)
     - `https://www.googleapis.com/auth/gmail.send` (restricted scope for sending emails)
   - Save the configuration

4. **Add Test Users (while in Testing mode):**
   - Go to *Test users* section in the OAuth consent screen
   - Click **Add Users** and add the Gmail account(s) you want to test with
   - This is required until your application completes Google's verification process

5. **Enable the Gmail API:**
   - Go to *APIs & Services* → **Library**
   - Search for "Gmail API" and click **Enable**

6. **Create OAuth 2.0 Credentials:**
   - Go to *APIs & Services* → **Credentials**
   - Click **Create Credentials** → **OAuth client ID**
   - Choose *Web application* as the application type
   - Under *Authorized redirect URIs*, add:
     - `http://localhost:5000/users/auth/google_oauth2/callback` (development)
     - Your production URL when available
   - Copy the **Client ID** and **Client Secret**

7. **Configure Your Rails App:**
   - Add to your `.env` file:
     ```env
     GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
     GOOGLE_CLIENT_SECRET=your-client-secret
     ```
   - Restart `bin/dev` to reload environment variables

8. **Test the Connection:**
   - Navigate to your profile page in the Rails app
   - Click **"Connecter Gmail"**
   - Follow Google's authentication flow
   - After successful consent, a success badge should appear confirming Gmail connection

## 📚 Documentation

- **[Specifications](docs/specs%20fonctionnelles.md)** - Functional requirements and workflows
- **[Rails Architecture](docs/architecture%20rails.md)** - Data models, controllers, services
- **[Repository Architecture](docs/architecture%20repo.md)** - Service contracts and communication

## 🧪 Testing

### Rails Tests
```bash
cd rails_app
bin/rails test              # All tests
bin/rails test:system       # Browser-based system tests
```

### Python Tests
```bash
source python_services/api/.venv/bin/activate
pytest python_services/     # All tests
pytest -v --cov            # With verbose output and coverage
```

## 🐘 Database

### PostgreSQL Management

```bash
# Start PostgreSQL (auto-started by bin/setup)
sudo service postgresql start

# Connect to Rails database
sudo -u postgres psql rails_app_development

# Reset database
cd rails_app && bin/rails db:reset
```

### Database Schemas

Rails uses multiple databases configured in `config/database.yml`:
- **Main database** - User, CV, job applications
- **Solid Queue database** - Background jobs
- **Solid Cache database** - Application cache
- **Solid Cable database** - WebSocket connections

## 🚨 Troubleshooting

### `foreman: command not found`
```bash
gem install foreman
# Or run bin/setup again
```

### PostgreSQL connection refused
```bash
sudo service postgresql start
# Then restart services: bin/dev
```

### Python dependencies conflict
```bash
cd python_services/api
rm -rf .venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Playwright browser issues
```bash
source python_services/api/.venv/bin/activate
playwright install
sudo apt-get install libglib2.0-0 libnss3 libgconf-2-4 libxi6
```

## 📝 Git Workflow

```bash
# Create a feature branch
git checkout -b feature/your-feature

# Make changes and commit
git add .
git commit -m "feat: description"

# Push and create PR
git push origin feature/your-feature
```

## 🤝 Contributing

1. Follow the existing code style (Rubocop, Black, Ruff)
2. Write tests for new features
3. Update documentation in `docs/`
4. Run `bin/ci` before pushing
5. Create a pull request with clear description

## 📞 Support

For questions or issues:
- Check the documentation in `docs/`
- Review existing issues
- Create a new issue with detailed description

## 📄 License

See LICENSE file for details.
