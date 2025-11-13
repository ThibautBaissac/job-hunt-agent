# 1. Vision & objectifs métier

**Vision**

Un agent de candidature à des offres d’emploi  :

> Tu colles une offre → l’agent comprend → il prépare mail + lettre + recommandations CV → tu vérifies → tu envoies → c’est loggé dans mon Kanban.
>

**Objectifs principaux**

1. **Réduire le temps par candidature** (de 30–45 min à < 10 min).
2. **Augmenter la qualité moyenne** des candidatures (meilleur matching + personnalisation).
3. **Structurer ta recherche d’emploi** dans un pipeline visuel (Kanban).
4. **Préparer le terrain** pour plus d’automatisation plus tard (mais v1 = toujours validation manuelle).

---

# 2. Périmètre fonctionnel V1

Inclut :

- Candidature “1-clic” manuelle à partir d’une offre :
    - Source : **LinkedIn** ou **Welcome to the Jungle** (WTTJ).
    - Import de l’offre via URL ou copié/collé.
- Analyse automatique de l’offre & matching avec mon **CV principal**.
- Génération :
    - **Email de candidature** personnalisé.
    - **Lettre de motivation courte** (facultative mais générée).
    - Suggestions d’**adaptation du CV** (structure & contenu, pas encore génération de PDF complexe).
- Envoi d’email via **API Gmail**, après validation humaine obligatoire.
- **Tableau de bord + Kanban** pour suivre toutes les candidatures.
- **Analyse & optimisation du CV via IA** (hors offres, mode “standalone”).
- Base technique extensible pour :
    - Ajouter d’autres plateformes,
    - Automatiser des parties du workflow plus tard.

Exclut (pour V1) :

- Postuler automatiquement via formulaires LinkedIn/WTTJ.
- Scraping massif / automatisé de listes d’offres.
- Recherche automatique d’emails de recruteurs.
- Envoi d’emails sans validation humaine.
- Multi-utilisateurs (V1 centrée sur *toi*).

---

# 3. Personas & cas d’usage

### Persona principal

- **Toi** : développeur Ruby on Rails, profil technique, à l’aise avec les outils, prêt à relire et corriger les textes générés.
- Utilisation quotidienne : 1 à 10 candidatures / jour.

### Cas d’usage principaux

1. **CU1 – Candidater en 1 clic à une offre LinkedIn ou WTTJ**
2. **CU2 – Suivre toutes mes candidatures dans un Kanban**
3. **CU3 – Améliorer mon CV de manière itérative avec l’IA**
4. **CU4 – Personnaliser mes modèles d’emails & lettres**
5. **CU5 – Consulter l’historique & les stats (optionnel v1 light)**

---

# 4. Parcours utilisateur principaux

### 4.1. Parcours “Postuler à une offre en 1 clic”

1. L’utilisateur copie l’URL d’une offre **LinkedIn ou WTTJ**.
2. Il ouvre l’app et clique sur **“Nouvelle candidature”**.
3. Il colle l’URL (ou le texte de l’offre).
4. Le système :
    - Extrait ou parse :
        - Titre du poste,
        - Entreprise,
        - Localisation,
        - Stack technique,
        - Niveau d’expérience,
        - Description / missions,
        - Mots-clés.
5. Le système matche l’offre avec le **CV principal** :
    - Identifie compétences pertinentes,
    - Repère les expériences/projets à mettre en avant,
    - Détecte éventuellement les gaps.
6. L’IA génère :
    - Un **email de candidature** (ou message LinkedIn si l’adresse n’est pas connue → version email générique).
    - Une **lettre de motivation courte** (2–3 paragraphes).
    - Une liste de **suggestions d’adaptation du CV** (ordre des sections, phrases à modifier, éléments à ajouter).
7. L’utilisateur voit un écran de révision :
    - Offre résumée,
    - Matching CV / offre,
    - Email proposé (modifiable),
    - Lettre proposée (modifiable),
    - Suggestions CV.
8. L’utilisateur :
    - Modifie / valide le contenu,
    - Clique sur **“Envoyer par email”** (si l’email de contact est connu / renseigné),
    - Ou copie le texte pour le coller manuellement ailleurs (LinkedIn, formulaire, etc.).
9. Si envoi par Gmail :
    - L’email est envoyé via l’API Gmail.
10. La candidature est :
    - Créée dans la base,
    - Ajoutée à la colonne **“Envoyée”** du Kanban.

---

### 4.2. Parcours “Suivi des candidatures (Kanban)”

1. L’utilisateur ouvre le **Tableau de bord**.
2. Il voit un Kanban avec par défaut les colonnes :
    - **À traiter**
    - **En cours de préparation**
    - **Envoyée**
    - **Entretien**
    - **Offre**
    - **Refus / Sans réponse**
3. Chaque carte contient :
    - Nom de l’entreprise,
    - Titre du poste,
    - Date de création / envoi,
    - Plateforme (LinkedIn / WTTJ / autre),
    - Dernière action,
    - Lien vers l’offre,
    - Indicateur de matching (score ou tags).
4. L’utilisateur peut :
    - Déplacer une carte par drag & drop.
    - Ouvrir la fiche détaillée :
        - Historique des emails envoyés,
        - Notes,
        - Résumé de l’offre,
        - Version de l’email envoyé.
    - Ajouter des notes (compte-rendu d’entretien, feedback recrut…).

---

### 4.3. Parcours “Analyse & optimisation du CV”

1. L’utilisateur va dans **“Mon CV”**.
2. Il :
    - Upload un PDF ou colle son CV en texte (V1 : texte recommandé).
3. Le système :
    - Stocke la version comme **“CV principal”**.
    - Analyse :
        - Structure (sections, clarté),
        - Lisibilité,
        - Clarté des expériences,
        - Alignement avec les postes ciblés (via paramètres de recherche ou exemples d’offres).
4. L’IA renvoie :
    - Une **analyse qualitative** (forces/faiblesses),
    - Des suggestions d’améliorations :
        - Formulation,
        - Ajout de résultats chiffrés,
        - Mise en avant des bonnes expériences,
        - Adaptation à un type de poste cible (backend, fullstack, etc.).
5. L’utilisateur peut :
    - Accepter / refuser certaines suggestions,
    - Générer une **nouvelle version** du CV (au moins en texte pour l’instant),
    - Taguer la version : “CV généraliste”, “CV Rails backend”, etc.

---

# 5. Spécifications fonctionnelles par module

## 5.1. Module Utilisateur & Profil

- **Fonctionnalités**
    - Connexion simple (V1 possible sans multi-user, mais prévoir un modèle User).
    - Configuration du profil :
        - Nom, email principal,
        - Titre/position,
        - Localisation,
        - URL GitHub / portfolio / LinkedIn.
    - Connexion à Gmail via OAuth.
- **Règles**
    - Un utilisateur ne peut envoyer des emails qu’après avoir connecté Gmail.
    - Les informations de profil peuvent être utilisées dans les emails / lettres (placeholders).

---

## 5.2. Module CV & Documents

- **Fonctionnalités**
    - Stocker un **CV principal** (texte structuré).
    - Option : uploader un fichier (PDF) → extraction texte (même si pas parfait).
    - Gestion de versions :
        - Marquer une version comme “active”.
        - Historiser les modifications.
- **IA**
    - Analyser le CV (voir 4.3).
    - Extraire :
        - Compétences techniques (langages, frameworks, outils),
        - Expériences (titre, entreprise, dates, stack),
        - Types de missions (produit, agence, freelance…).
- **Contraintes**
    - L’IA ne doit pas pouvoir **inventer de nouvelles expériences** sans validation explicite.
    - Les suggestions doivent être présentées comme : “Proposition de reformulation”.

---

## 5.3. Module Offres (LinkedIn / WTTJ)

- **Fonctionnalités**
    - Création d’une offre dans le système à partir :
        - D’une **URL LinkedIn ou WTTJ**,
        - Ou d’un **copié/collé** de la description.
    - Extraction / parsing :
        - Plateforme (LinkedIn / WTTJ / Autre),
        - Titre du poste,
        - Entreprise,
        - Localisation,
        - Type (CDI, freelance, stage…),
        - Niveau d’expérience,
        - Stack technique,
        - Description brute.
- **IA**
    - Enrichir l’offre avec :
        - Mots-clés,
        - Tags stack (Ruby, Rails, API, PostgreSQL, etc.),
        - Soft skills,
        - Contexte (produit / ESN / consulting… si inférable).
- **Règles**
    - Si extraction automatique échoue, l’utilisateur peut corriger / compléter manuellement.
    - Chaque candidature est toujours liée à une offre.

---

## 5.4. Module Matching CV ⇄ Offre

- **Fonctionnalités**
    - Calcul d’un **score de matching** (ex: 0–100) basé sur :
        - Compétences techniques communes,
        - Expériences proches du besoin,
        - Mots-clés partagés.
    - Affichage :
        - Liste des **points forts** (matching),
        - Liste des **manques ou points à adoucir**.
- **IA**
    - Utiliser un LLM / embeddings pour :
        - Comparer les phrases d’expérience avec les exigences du poste.
        - Générer un résumé du matching :
            - “Tu es très aligné sur la stack backend…”
            - “Manque éventuel : expérience en management d’équipe…”
- **Règles**
    - Le score de matching est **indicatif**, jamais bloquant.
    - L’utilisateur peut ignorer les warnings.

---

## 5.5. Module Génération de contenu (IA)

- **Contenus gérés**
    - Email de candidature.
    - Lettre de motivation courte.
    - Suggestions de texte pour CV.
- **Paramètres**
    - Mon par défaut (pro, direct, friendly…).
    - Langue (FR / EN).
    - Modèles personnalisables :
        - Placeholder : {{nom_entreprise}}, {{poste}}, {{accroche_profil}}, etc.
- **Règles**
    - Le texte généré est toujours :
        - Visible en entier,
        - Modifiable à la main.
    - Jamais d’envoi sans passage par l’écran de validation.
    - L’IA ne doit pas créer de mensonges factuels (ex : “5 ans d’expérience React” si non présent dans le CV) → si nécessaire, phrases du type :
        - “Tu sembles avoir de l’expérience sur X, veux-tu le mentionner ?”

---

## 5.6. Module Candidature & Envoi Email (Gmail)

- **Fonctionnalités**
    - Création d’une candidature à partir d’une offre.
    - Saisie / récupération de l’email de contact :
        - Renseigné manuellement,
        - Ou trouvé dans l’offre si présent.
    - Écran de prévisualisation :
        - Destinataire,
        - Objet,
        - Corps de l’email,
        - Pièces jointes (CV principal ou version spécifique).
    - Envoi via Gmail API (OAuth).
    - Sauvegarde :
        - Statut de la candidature,
        - Date et heure d’envoi,
        - Contenu de l’email.
- **Règles**
    - Envoi uniquement **après clic explicite** sur “Envoyer”.
    - Possibilité de **sauvegarder en brouillon** sans envoyer.
    - Si envoi échoue (API Gmail), message d’erreur + possibilité de réessayer.

---

## 5.7. Tableau de bord & Kanban

- **Fonctionnalités**
    - Vue Kanban avec colonnes configurables (mais défaut fixé).
    - Filtres :
        - Plateforme,
        - Entreprise,
        - Période,
        - Statut.
    - Détails d’une candidature :
        - Offre liée (titre + lien),
        - Date de création / envoi,
        - Contenus générés (email, lettre),
        - Notes,
        - Matching score,
        - Historique des changements de statut.
- **Règles**
    - Changer de colonne met à jour le **statut**.
    - Certains statuts peuvent être définis uniquement via actions :
        - “Envoyée” suite à un envoi réel par l’app (sinon marquée comme “Envoyée (manuel)” si user le force).

---

## 5.8. Module Paramètres & Extensibilité

- **Fonctionnalités**
    - Personnalisation de :
        - Modèles d’emails,
        - Signatures,
        - Mon de l’écriture IA.
    - Activation de “modes d’automatisation” **futurs** :
        - Pré-remplir automatiquement les champs,
        - Pré-générer des candidatures à partir de favoris, etc.
- **Structure pour extension**
    - Chaque étape du flux de candidature (analyse offre, matching, génération, envoi) doit être isolée pour pouvoir :
        - être automatisée plus tard,
        - être déclenchée par des jobs en arrière-plan.

---

# 6. Règles métier clés (résumé)

1. **Toujours validation humaine avant envoi.**
2. Une candidature est toujours liée à :
    - Une **offre**,
    - Un **CV**,
    - (optionnel) une lettre de motivation.
3. L’IA :
    - Ne peut pas inventer d’expériences non présentes dans mon profil,
    - Propose, **tu disposes**.
4. L’envoi via Gmail :
    - Nécessite une connexion OAuth valide,
    - Enregistre systématiquement ce qui a été envoyé.
5. Le Kanban est la **source de vérité** pour le statut d’une candidature.
