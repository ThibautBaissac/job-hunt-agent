# 🟦 **Epic 0 — Architecture & communication inter-services**

---

### **US 0.1 – En tant que développeur, je veux une architecture mono-repo propre**

**Critères d’acceptation :**

- Le repo contient :
    - `/rails_app` (app métier + UI)
    - `/python_services/agent_api` (agent LangChain)
    - `/python_services/scraper_api` (scraping Playwright)
    - `.env` à la racine
- Une documentation `README` explique le setup.

---

### **US 0.2 – En tant que développeur, je veux que les services communiquent en HTTP**

**Critères d’acceptation :**

- Rails peut envoyer :
    - POST `AGENT_API_URL/agent/job_application`
    - POST `SCRAPER_API_URL/scrape/offer`
- Réponses en JSON structurées.
- Timeout & error handling définis.

---

### **US 0.3 – En tant que développeur, je veux pouvoir lancer Rails + Agent API + Scraper API en local**

**Critères d’acceptation :**

- 3 services peuvent tourner en parallèle :
    - Rails (3000)
    - Agent API (8001)
    - Scraper API (8002)
- Via Docker compose **OU** via 3 terminaux.
- Rails lit `.env` pour trouver les URLs des services.

---

# 🟦 **Epic 1 — Gestion du compte utilisateur & configuration**

---

### **US 1.1 – Créer un compte utilisateur**

**Critères d’acceptation :**

- Inscription & connexion disponibles.
- Email unique, validation d’email.
- Déconnexion possible.

---

### **US 1.2 – Configurer mon profil professionnel**

**Critères d’acceptation :**

- Je peux définir :
    - nom complet
    - titre/position
    - ville
    - URLs (GitHub, LinkedIn)
    - signature par défaut
    - langue par défaut
    - ton d’écriture IA
- Les valeurs sont sauvegardées.

---

### **US 1.3 – Connecter Gmail (OAuth)**

**Critères d’acceptation :**

- Un bouton “Connecter Gmail”.
- OAuth Google fonctionne.
- Un message indique le statut “Gmail connecté”.

---

# 🟦 **Epic 2 — Gestion du CV & amélioration IA (via Agent API)**

---

### **US 2.1 – Importer mon CV**

**Critères d’acceptation :**

- Je peux coller mon CV en texte.
- Ou uploader un PDF → extraction texte.
- Le CV est enregistré comme “CV principal”.

---

### **US 2.2 – Analyser mon CV via l’Agent API**

**Critères d’acceptation :**

- En cliquant “Analyser mon CV” :
    - Rails envoie `cv_text` → Agent API `/agent/cv_analysis`
- L’Agent renvoie :
    - forces
    - faiblesses
    - suggestions d’amélioration
- Les résultats s’affichent dans l’UI.

---

### **US 2.3 – Enregistrer une version optimisée du CV**

**Critères d’acceptation :**

- Je peux accepter / modifier les suggestions.
- Le CV optimisé est enregistré comme nouvelle version.
- Je peux marquer une version “active”.

---

# 🟦 **Epic 3 — Import d’offres (via Scraper API + fallback texte)**

---

### **US 3.1 – Importer une offre en collant une URL LinkedIn ou WTTJ**

**Critères d’acceptation :**

- Je colle une URL dans l’app Rails.
- Rails envoie : `POST /scrape/offer` avec `{url}`.
- Le Scraper API renvoie :
    - `title`
    - `company`
    - `location`
    - `description`
    - `platform` (linkedin / wttj)
- Rails crée un `JobOffer`.

---

### **US 3.2 – Importer une offre via texte collé (fallback)**

**Critères d’acceptation :**

- Si scraping échoue :
    - Rails propose de coller la description manuellement.
- Une `JobOffer` “platform:other” est créée.

---

### **US 3.3 – Résumé IA de l’offre (Agent API)**

**Critères d’acceptation :**

- Rails envoie :
    - `job_offer.description` → `/agent/offer_analysis`.
- L’agent renvoie :
    - résumé,
    - stack technique détectée,
    - mots-clés importants,
    - niveau d’expérience.
- Les données sont affichées et éditables.

---

# 🟦 **Epic 4 — Matching CV ⇄ Offre (Agent API)**

---

### **US 4.1 – Calculer un score de matching via l’Agent**

**Critères d’acceptation :**

- Rails appelle `/agent/job_match` avec :
    - texte du CV
    - description de l’offre
- L’Agent renvoie :
    - `match_score` (0-100)
    - `strengths`
    - `gaps`
- Le score s’affiche sur la fiche candidature.

---

### **US 4.2 – Afficher les forces et faiblesses**

**Critères d’acceptation :**

- Deux sections s’affichent :
    - “Points forts”
    - “Points à améliorer”
- Explications claires (texte agent).

---

# 🟦 **Epic 5 — Génération IA du mail, lettre, suggestions CV (Agent API)**

---

### **US 5.1 – Générer un email de candidature personnalisé**

**Critères d’acceptation :**

- Rails envoie :
    - `job_offer`
    - `cv`
    - `profile`
    - `email_template`
    → `/agent/generate_email`
- L’Agent renvoie :
    - subject
    - body
- Le mail est éditable par l’utilisateur.

---

### **US 5.2 – Générer une lettre de motivation courte**

**Critères d’acceptation :**

- Rails appelle `/agent/generate_cover_letter`
- L’agent renvoie un texte optimisé et contextualisé.
- L’utilisateur peut éditer avant validation.

---

### **US 5.3 – Générer des suggestions d’adaptation du CV pour cette offre**

**Critères d’acceptation :**

- Rails appelle `/agent/generate_cv_suggestions`
- L’agent renvoie des recommandations :
    - sections à bouger
    - formulations à renforcer
    - compétences à mettre en avant
- Aucune modification du CV sans action humaine.

---

# 🟦 **Epic 6 — Envoi d’emails via Gmail API**

---

### **US 6.1 – Prévisualiser l’email avant envoi**

**Critères d’acceptation :**

- Un écran affiche :
    - destinataire
    - sujet
    - corps
    - pièce jointe (CV actif)
- Modifications possibles.

---

### **US 6.2 – Envoyer l’email via Gmail (Gmail API)**

**Critères d’acceptation :**

- L’utilisateur clique “Envoyer”.
- Rails appelle `Integrations::GmailClient`.
- Si succès :
    - Application.status → `sent`
    - sent_at enregistré
    - copie sauvegardée dans `SentEmail`.
- Si erreur : message clair + retry possible.

---

# 🟦 **Epic 7 — Kanban & suivi**

---

### **US 7.1 – Voir toutes mes candidatures dans un Kanban**

**Critères d’acceptation :**

- Colonnes par défaut :
    - `to_process`
    - `preparing`
    - `sent`
    - `interview`
    - `offer`
    - `rejected`
    - `no_answer`
- Chaque carte montre :
    - titre
    - entreprise
    - date
    - match_score

---

### **US 7.2 – Modifier le statut via drag & drop**

**Critères d’acceptation :**

- Déplacement d’une carte → mise à jour DB.
- Historique de changement de statut dans la fiche candidature.

---

### **US 7.3 – Ajouter des notes à une candidature**

**Critères d’acceptation :**

- Ajout de notes horodatées.
- Notes listées en dessous.
- Jamais modifiées par l’IA.

---

# 🟦 **Epic 8 — Modèles et paramètres IA**

---

### **US 8.1 – Modifier mes modèles d’emails**

**Critères d’acceptation :**

- Je peux éditer :
    - subject template
    - body template
- Placeholders disponibles :
    - {{nom_entreprise}}
    - {{poste}}
    - {{accroche}}
    - {{signature}}

---

### **US 8.2 – Définir mon ton d’écriture IA**

**Critères d’acceptation :**

- Choix entre plusieurs tons.
- L’Agent API utilise ce ton dans toutes ses générations.

---

# 🟦 **Epic 9 — Extensibilité & préparation à l’automatisation**

---

### **US 9.1 – Chaque étape doit être isolée (SRP) pour permettre une automatisation plus tard**

**Critères d’acceptation :**

- Analyse, matching, génération, envoi sont séparés.
- Appels à l’Agent API découplés.
- ApplicationWorkflow orchestré proprement côté Rails.

---

### **US 9.2 – Les connecteurs d’offres doivent être extensibles**

**Critères d’acceptation :**

- Scraper API utilise une interface simple :
    - `scrape(url)`
    - parser associé à chaque plateforme.
- Ajouter une nouvelle source = ajouter un parser dans `/parsers`.
