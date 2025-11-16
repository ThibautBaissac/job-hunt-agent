"""Offer analysis endpoint exposed by the Agent API."""
from fastapi import APIRouter, HTTPException, status
import logging

from ..core.offer_analysis import generate_offer_analysis
from ..schemas import OfferAnalysisRequest, OfferAnalysisResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/agent", tags=["offer_analysis"])

MAX_ATTEMPTS = 2


@router.post("/offer_analysis", response_model=OfferAnalysisResponse, status_code=status.HTTP_200_OK)
async def post_offer_analysis(payload: OfferAnalysisRequest) -> OfferAnalysisResponse:
    """Perform an offer analysis with a retry before surfacing an error."""

    last_error: Exception | None = None

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            analysis = generate_offer_analysis(payload)
            return OfferAnalysisResponse(data=analysis)
        except Exception as exc:  # pragma: no cover - safeguard for unforeseen runtime failures
            last_error = exc
            logger.exception("Offer analysis attempt %s failed", attempt)

    detail = "Offer analysis failed after retry." if last_error else "Offer analysis unavailable."
    raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=detail)
