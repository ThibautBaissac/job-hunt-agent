## 1. Vue d’ensemble du domaine

Objets métier principaux :

- **User** : les utilisateurs.
- **Profile** : ton profil pro (nom, titre, liens…).
- **Cv** : différentes versions de ton CV (texte).
- **JobOffer** : une offre importée (LinkedIn/WTTJ/texte).
- **Application** : une candidature pour une offre donnée.
- **ApplicationNote** : notes d’entretien & suivi.
- **EmailTemplate** : modèles d’email personnalisables.
- **SentEmail** : trace des emails envoyés via Gmail.

Le Kanban = simplement **Application.status** (enum) affiché par colonnes côté UI.

L’IA & Gmail restent dans des **services** (SRP) + quelques jobs.

---

## 2. Modèles, relations, validations

### 2.1. User & Profile

**User**

- Relations :
    - has_one :profile
    - has_many :cvs
    - has_many :job_offers
    - has_many :applications
    - has_many :email_templates
- Champs clés :
    - email (unique)
    - encrypted_password
    - google_uid (pour Gmail)
    - gmail_connected:boolean
- Validations :
    - presence : email
    - format email
    - uniqueness email

**Profile**

- belongs_to :user
- Champs :
    - full_name
    - headline / job_title
    - location
    - github_url
    - linkedin_url
    - default_signature_text
    - default_language (fr/en)
    - default_tone (enum : :pro, :direct, :chaleureux, etc.)
- Validations :
    - presence : full_name
    - format : github_url / linkedin_url (URL)

---

### 2.2. CV

**Cv**

- belongs_to :user
- Champs :
    - title (ex: “CV Backend Rails”)
    - body_text (texte brut structuré)
    - active:boolean
    - last_analysis_text (retour IA stocké)
- Validations :
    - presence : title, body_text
    - uniqueness : active CV par user (via validation custom)

Idée KISS : pas de table à part pour “analysis” pour l’instant, tu stockes juste la dernière analyse en texte.

---

### 2.3. JobOffer

**JobOffer**

- belongs_to :user
- a une ou plusieurs applications :
    - has_many :applications
- Champs :
    - source (enum : :linkedin, :wttj, :other)
    - source_url
    - title
    - company_name
    - location
    - contract_type (string ou enum simple : CDI, Freelance, Stage…)
    - seniority_level (string / enum)
    - raw_description (texte complet)
    - summary (texte IA)
    - tech_stack (jsonb : liste de techno + tags)
- Validations :
    - presence : title, company_name
    - format : source_url (URL)
    - inclusion : source dans l’enum

---

### 2.4. Application (Candidature) & notes

**Application**

- belongs_to :user
- belongs_to :job_offer
- belongs_to :cv (version utilisée pour cette candidature)
- has_many :application_notes
- has_many :sent_emails
- Champs :
    - status (enum Kanban : :to_process, :preparing, :sent, :interview, :offer, :rejected, :no_answer)
    - contact_email
    - applied_via (enum : :email, :linkedin_message, :other)
    - match_score (float)
    - sent_at (datetime)
    - last_status_change_at
- Validations :
    - presence : job_offer, cv, status
    - format : contact_email
    - match_score entre 0 et 100 (si présent)

**ApplicationNote**

- belongs_to :application
- belongs_to :user
- Champs :
    - body (texte)
- Validations :
    - presence : body

---

### 2.5. Emails & templates

**EmailTemplate**

- belongs_to :user
- Champs :
    - name (ex : “Candidature standard FR”)
    - subject_template
    - body_template
    - language (enum : fr, en)
    - tone (enum, aligné avec Profile)
- Validations :
    - presence : name, body_template

**SentEmail**

- belongs_to :application
- belongs_to :user
- Champs :
    - provider (string, ex : “gmail”)
    - to
    - subject
    - body
    - sent_at
    - external_id (id du message côté Gmail)
- Validations :
    - presence : to, subject, body, sent_at

---

## 3. Services (SRP, small & focused)

Tout ce qui est logique métier “un peu intelligente” est dans des services/ POROs.

### 3.1. Import / parsing d’offre

Namespace : `OfferImporters`

- **OfferImporters::LinkedinImporter**
    - Responsabilité : à partir d’une URL LinkedIn, récupérer HTML, parser titre / entreprise / description.
- **OfferImporters::WttjImporter**
    - Idem pour WTTJ.
- **OfferImporters::TextImporter**
    - Responsabilité : créer une JobOffer à partir d’un texte collé (sans scraping).

### 3.2. Analyse IA

Namespace : `Ai`

- **Ai::OfferAnalyzer**
    - Entrée : job_offer.raw_description
    - Sortie :
        - summary
        - tech_stack (json)
        - missions clés
        - niveau d’expérience
- **Ai::CvAnalyzer**
    - Entrée : cv.body_text (+ éventuellement profil cible).
    - Sortie :
        - analyse (forces/faiblesses)
        - suggestions générales
- **Ai::Matcher**
    - Entrée : cv + job_offer
    - Sortie :
        - match_score
        - points forts
        - gaps
- **Ai::EmailGenerator**
    - Entrée : user.profile, cv, job_offer, email_template
    - Sortie :
        - subject, body (email de candidature)
- **Ai::CoverLetterGenerator**
    - Entrée : même chose, éventuellement plus détaillé
    - Sortie :
        - texte de lettre de motivation

Chacun fait **une seule chose** : tu peux les faire évoluer indépendamment.

---

### 3.3. Intégration Gmail

Namespace : `Mailers` ou `Integrations`

- **Integrations::GmailClient**
    - Responsabilité :
        - gérer l’auth OAuth (token/refresh),
        - envoyer un email (to, subject, body, pièces jointes),
        - retourner `external_id` / status.
    - Ne connaît pas les Applications ni les Candidatures : juste “je parle à Gmail”.

### 3.4. Workflow de candidature

Namespace : `ApplicationWorkflow`

- **ApplicationWorkflow::Builder**
    - Responsabilité :
        - Créer une JobOffer (ou la lier si déjà existante),
        - Créer une Application,
        - Appeler les services IA (OfferAnalyzer, Matcher),
        - Préparer les données pour l’écran de révision.
- **ApplicationWorkflow::Sender**
    - Responsabilité :
        - Appeler GmailClient,
        - Créer un SentEmail,
        - Mettre à jour Application (status: :sent, sent_at…).

---

## 4. Background jobs

Utilise solid_queue.

- **OfferAnalysisJob**
    - Appelle `Ai::OfferAnalyzer` sur une JobOffer.
- **CvAnalysisJob**
    - Appelle `Ai::CvAnalyzer` sur un Cv.
- **MatchingJob**
    - Appelle `Ai::Matcher` pour cv + job_offer et met à jour Application.match_score.
- **EmailSendJob**
    - Appelle `ApplicationWorkflow::Sender` pour envoyer un email en async (avec retry).

---

## 5. Routes principales (REST + quelques actions custom)

Pas de code détaillé, juste la structure.

### 5.1. Profil & utilisateur

- `resource :profile, only: [:show, :edit, :update]`
- Auth standard (Devise ou maison) :
    - sessions, registrations

### 5.2. CV

- `resources :cvs, only: [:index, :show, :create, :update, :destroy]`
    - member `POST /cvs/:id/analyze` → lance `CvAnalysisJob`
    - member `POST /cvs/:id/activate` → set active

### 5.3. Offres

- `resources :job_offers, only: [:index, :show, :create, :update, :destroy]`
    - `POST /job_offers/import_url` → crée + parse depuis URL (LinkedIn/WTTJ)
    - `POST /job_offers/import_text` → crée depuis texte libre
    - member `POST /job_offers/:id/analyze` → IA

### 5.4. Candidatures

- `resources :applications, only: [:index, :show, :create, :update]`
    - member `POST /applications/:id/generate_content`

        → appelle Ai::EmailGenerator + Ai::CoverLetterGenerator

    - member `POST /applications/:id/send_email`

        → déclenche EmailSendJob / Sender

    - member `PATCH /applications/:id/change_status`

        → pour drag & drop du Kanban


### 5.5. Notes

- `resources :applications do`
    - `resources :application_notes, only: [:create, :update, :destroy]`
- Simple et imbriqué, KISS.

### 5.6. Email templates

- `resources :email_templates, only: [:index, :show, :create, :update, :destroy]`

### 5.7. Intégration Gmail / OAuth

- route pour lancer OAuth Google :
    - `GET /auth/google_oauth2`
    - `GET /auth/google_oauth2/callback`

        → contrôleur qui met à jour User (google_uid, gmail_connected, tokens…)
