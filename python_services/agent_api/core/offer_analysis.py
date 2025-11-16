"""LangChain-powered offer analysis backed by Anthropic Claude."""
from __future__ import annotations

import logging
import os
from functools import lru_cache
from textwrap import dedent

from langchain_anthropic import ChatAnthropic
from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate

from ..schemas import OfferAnalysisData, OfferAnalysisRequest

logger = logging.getLogger(__name__)

DEFAULT_MODEL = "claude-3-5-sonnet-20241022"
MAX_DESCRIPTION_CHARS = 6000

SYSTEM_PROMPT = dedent(
    """
    Tu es un expert en analyse d'offres d'emploi techniques. Ta mission est de lire les informations
    fournies par l'utilisateur et de produire une analyse structurée en français.

    Tu dois impérativement respecter les instructions de format JSON suivantes :
    {format_instructions}

    Consignes supplémentaires :
    - Résume l'offre en 2 à 3 phrases concises, sans phrases génériques.
    - Déduis la liste des technologies réellement mentionnées (5 à 10 éléments max).
    - Identifie des mots-clés utiles pour un candidat (5 à 10 éléments max), en conservant
      la casse naturelle des termes métier et méthodes.
    - Donne le niveau de séniorité attendu (Junior, Intermédiaire, Senior, Lead, Staff, etc.).
    - Si une information est absente, renvoie une valeur vide (« » ou liste vide) plutôt
      que d'inventer du contenu.
    - N'ajoute jamais de texte en dehors du JSON demandé.
    """
)


def generate_offer_analysis(payload: OfferAnalysisRequest) -> OfferAnalysisData:
    """Invoke the Anthropic model through LangChain and build the structured analysis."""

    description = (payload.job_offer.description or "").strip()
    if not description:
        title = payload.job_offer.title or "offre"
        logger.info("Offer description missing; returning placeholder analysis for job %s", title)
        return OfferAnalysisData(summary=f"Aucune description disponible pour {title}.")

    analysis_input = _build_user_message(payload, description)

    try:
        result = _analysis_chain().invoke(
            {
                "analysis_input": analysis_input,
                "format_instructions": _parser().get_format_instructions(),
            }
        )
    except Exception as exc:  # pragma: no cover - relies on external service
        logger.exception("Offer analysis generation failed: %s", exc)
        raise

    if isinstance(result, OfferAnalysisData):
        return result

    # Defensive: parser should already return OfferAnalysisData, but we coerce if needed.
    return OfferAnalysisData(**result)


def _build_user_message(payload: OfferAnalysisRequest, description: str) -> str:
    job = payload.job_offer
    segments = ["Données de l'offre d'emploi à analyser:"]

    if job.title:
        segments.append(f"Titre du poste: {job.title}")
    if job.company_name:
        segments.append(f"Entreprise: {job.company_name}")
    if job.location:
        segments.append(f"Localisation: {job.location}")

    truncated_description = description[:MAX_DESCRIPTION_CHARS]
    if len(description) > MAX_DESCRIPTION_CHARS:
        truncated_description += "\n[Texte tronqué pour respecter la limite de contexte]"
    segments.append("Description:")
    segments.append(truncated_description)

    if payload.profile:
        profile_parts = []
        if payload.profile.summary:
            profile_parts.append(f"Résumé: {payload.profile.summary}")
        if payload.profile.experience_level:
            profile_parts.append(f"Niveau d'expérience: {payload.profile.experience_level}")
        if profile_parts:
            segments.append("Profil du candidat:")
            segments.extend(profile_parts)

    if payload.cv and payload.cv.content:
        cv_excerpt = payload.cv.content.strip()
        if cv_excerpt:
            cv_excerpt = cv_excerpt[:1000]
            if len(payload.cv.content.strip()) > 1000:
                cv_excerpt += "\n[Extrait du CV tronqué]"
            segments.append("Contenu du CV (extrait):")
            segments.append(cv_excerpt)

    if payload.template and payload.template.body:
        template_excerpt = payload.template.body.strip()
        if template_excerpt:
            template_excerpt = template_excerpt[:800]
            if len(payload.template.body.strip()) > 800:
                template_excerpt += "\n[Extrait du modèle tronqué]"
            segments.append("Modèle fourni par l'utilisateur (extrait):")
            segments.append(template_excerpt)

    return "\n".join(segment for segment in segments if segment)


@lru_cache(maxsize=1)
def _analysis_chain():
    if not os.getenv("ANTHROPIC_API_KEY"):
        raise RuntimeError("ANTHROPIC_API_KEY manquant pour l'analyse via Agent API.")

    prompt = ChatPromptTemplate.from_messages(
        [
            ("system", SYSTEM_PROMPT),
            ("human", "{analysis_input}"),
        ]
    )

    llm = ChatAnthropic(
        model=_resolve_model_name(),
        temperature=0.2,
        max_tokens=800,
    )

    return prompt | llm | _parser()


@lru_cache(maxsize=1)
def _parser() -> PydanticOutputParser:
    return PydanticOutputParser(pydantic_object=OfferAnalysisData)


@lru_cache(maxsize=1)
def _resolve_model_name() -> str:
    model = os.getenv("LLM_MODEL", DEFAULT_MODEL).strip()
    return model or DEFAULT_MODEL
