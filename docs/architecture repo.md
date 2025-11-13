## 1. Structure générale du mono-repo

```
job-hunt-agent/
├── README.md
├── docker-compose.yml              # optionnel mais recommandé
├── .env                            # variables de dev (non commit)
│
├── rails_app/                      # ton app principale
│   ├── Gemfile
│   ├── config/
│   ├── app/
│   └── ...
│
└── python_services/                # tout ce qui est "agent" & scraping
    ├── agent_api/                  # service HTTP d'orchestration IA (LangChain etc.)
    │   ├── pyproject.toml / requirements.txt
    │   ├── agent_api/
    │   │   ├── __init__.py
    │   │   ├── main.py             # FastAPI/Flask entrypoint
    │   │   ├── routers/
    │   │   │   ├── agent.py        # /agent/job_application
    │   │   └── core/
    │   │       ├── chains.py       # définition LangChain
    │   │       └── models.py       # schémas Pydantic pour les payloads
    │   └── ...
    │
    └── scraper_api/                # service HTTP Playwright (ou intégré au même)
        ├── pyproject.toml / requirements.txt
        ├── scraper_api/
        │   ├── __init__.py
        │   ├── main.py             # /scrape/offer
        │   ├── playwright_client.py
        │   └── parsers/
        │       ├── linkedin.py
        │       └── wttj.py
        └── ...

```

---

## 2. Rôle de chaque bloc

### `rails_app/` (monolithe métier + UI)

- Modèles : User, Profile, Cv, JobOffer, Application, EmailTemplate, SentEmail, etc.
- Services Ruby :
    - `Agent::Client` → parle à `agent_api`
    - `Integrations::OfferScraperClient` → parle à `scraper_api`
    - `Integrations::GmailClient` → parle à Gmail
- Background jobs (ActiveJob) qui appellent ces services.
- UI :
    - Formulaire “nouvelle offre” (avec URL)
    - Page de préparation de candidature
    - Kanban

### `python_services/agent_api/`

- Framework : **FastAPI**.
- Endpoints typiques :
    - `POST /agent/job_application`

        Entrée : `job_offer`, `cv`, `profile`, `template`

        Sortie : `summary`, `match_score`, `email`, `cover_letter`, `cv_suggestions`

    - `POST /agent/cv_analysis`

        Entrée : texte du CV

        Sortie : analyse + suggestions

- Interne : LangChain + tools, prompts, etc.

### `python_services/scraper_api/`

- Framework : FastAPI aussi (recyclage).
- Endpoints :
    - `POST /scrape/offer` avec `{ "url": "..." }`

        Sortie : `{ title, company, location, description, platform }`

- Interne :
    - Playwright (mode headless),
    - Sélecteurs HTML spécifiques pour LinkedIn/WTTJ.

---

## 3. Communication Rails ↔ Python en local

Communication HTTP en JSON.

### 3.1. Variables d’environnement dans la racine

Fichier `.env` (non commité) à la racine :

```bash
# Rails
RAILS_ENV=development

# Services Python
AGENT_API_URL=http://localhost:8001
SCRAPER_API_URL=http://localhost:8002

# OpenAI ou autre provider
OPENAI_API_KEY=sk-...

# Gmail
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

```

Côté Rails, `dotenv-rails` pour `.env`.

### 3.2. Clients HTTP côté Rails

**2 services** (uniquement conceptuellement ici) :

- `app/services/agent/client.rb`
    - lit `ENV["AGENT_API_URL"]`
    - POST `/agent/job_application`
- `app/services/integrations/offer_scraper_client.rb`
    - lit `ENV["SCRAPER_API_URL"]`
    - POST `/scrape/offer`

Chaque service :

- Envoie du JSON,
- Reçoit du JSON,
- Lève des erreurs claires si :
    - timeout,
    - 4xx / 5xx,
    - payload incomplet.

KISS :`Faraday`

---

## 4. docker-compose (optionnel mais très pratique)

Dans `job-hunt-agent/docker-compose.yml` :

```yaml
services:
  rails_app:
    build: ./rails_app
    ports:
      - "3000:3000"
    env_file:
      - .env
    depends_on:
      - agent_api
      - scraper_api
      - postgres
    # command: bundle exec rails s -b 0.0.0.0

  agent_api:
    build: ./python_services/agent_api
    ports:
      - "8001:8001"
    env_file:
      - .env

  scraper_api:
    build: ./python_services/scraper_api
    ports:
      - "8002:8002"
    env_file:
      - .env

  postgres:
    image: postgres:16
    environment:
      - POSTGRES_USER=rails
      - POSTGRES_PASSWORD=rails
      - POSTGRES_DB=job_hunt_dev
    ports:
      - "5432:5432"

```

---

## 5. Flux complet d’une feature côté repo

### Exemple : “Je colle une URL LinkedIn, j’obtiens une fiche offre”

1. **Rails** – contrôleur `JobOffersController#create_from_url`
    - reçoit URL,
    - appelle `Integrations::OfferScraperClient.scrape(url)`.
2. **Integrations::OfferScraperClient** (Rails)
    - POST `SCRAPER_API_URL/scrape/offer` avec `{ url: ... }`.
3. **scraper_api** (Python + Playwright)
    - FastAPI reçoit la requête,
    - Playwright ouvre la page, lit DOM, extrait :
        - title, company, location, description, platform
    - renvoie JSON.
4. **Rails**
    - construit un `JobOffer` avec les données retournées,
    - sauve en BDD,
    - redirige vers la page de préparation de candidature.

---

### Exemple : “Je clique sur Préparer candidature”

1. **Rails** – contrôleur `ApplicationsController#create` ou `#prepare`
    - récupère :
        - `JobOffer`
        - `Cv` actif
        - `Profile`
        - éventuellement `EmailTemplate` par défaut
    - appelle `Agent::Client.prepare_application(...)`.
2. **Agent::Client** (Rails)
    - POST `AGENT_API_URL/agent/job_application` avec un JSON structuré :
        - `{ job_offer: {...}, cv: {...}, profile: {...}, template: {...} }`.
3. **agent_api** (Python + LangChain)
    - Agent LangChain lit le contexte,
    - Appelle ses tools internes,
    - Renvoie :
        - `summary`
        - `match_score`
        - `email_subject`
        - `email_body`
        - `cover_letter`
        - `cv_suggestions`.
4. **Rails**
    - crée l’`Application` en BDD,
    - stocke le `match_score`,
    - affiche à l’écran :
        - résumé,
        - mail proposé,
        - lettre,
        - suggestions CV,
    - le user modifie, puis clique “Envoyer”.
5. **Envoi**
    - clic “Envoyer” → `ApplicationWorkflow::Sender` → `Integrations::GmailClient` → Gmail.

---

## 6. Organisation des fichiers côté Python (agent)

Pour rester SRP & KISS :

```
python_services/agent_api/agent_api/
├── main.py                # FastAPI app, routes
├── routers/
│   ├── job_application.py # endpoint /agent/job_application
│   └── cv_analysis.py     # endpoint /agent/cv_analysis
├── core/
│   ├── chains.py          # définition LangChain (job_application_chain, cv_analysis_chain)
│   ├── tools.py           # tools spécifiques (matching, rewriting, etc.)
│   └── config.py          # clés API, settings
└── models/
    ├── job_application.py # Pydantic: JobOfferInput, CvInput, ProfileInput, AgentResponse
    └── cv.py

```

Même logique côté `scraper_api`.
