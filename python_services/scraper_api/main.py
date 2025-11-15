"""FastAPI application exposing the job offer scraping endpoint."""
from __future__ import annotations

import logging
import os
from urllib.parse import urlparse

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .core.browser import BrowserConfig, BrowserSession
from .core.exceptions import NetworkError, ParsingError, UnsupportedPlatformError
from .parsers import LinkedinParser, WttjParser
from .schemas import JobOfferData, ScrapeRequest


load_dotenv(dotenv_path="../../.env")

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Job Hunt Scraper API",
    description="Web scraping service for job offers using Playwright",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


PARSER_REGISTRY = {
    "linkedin": LinkedinParser(),
    "wttj": WttjParser(),
}

DEFAULT_USER_AGENT = os.getenv(
    "SCRAPER_USER_AGENT",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
)
DEFAULT_LAUNCH_ARGS = ("--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu")


def _parse_timeout(value: str | None, fallback: int) -> int:
    try:
        return int(value) if value else fallback
    except (TypeError, ValueError):
        return fallback


def _parse_launch_args(value: str | None) -> tuple[str, ...]:
    if not value:
        return DEFAULT_LAUNCH_ARGS
    return tuple(arg for arg in value.split() if arg)


BROWSER_CONFIG = BrowserConfig(
    headless=os.getenv("SCRAPER_HEADLESS", "true").lower() not in {"0", "false", "no"},
    user_agent=os.getenv("SCRAPER_USER_AGENT", DEFAULT_USER_AGENT),
    page_timeout=_parse_timeout(os.getenv("SCRAPER_PAGE_TIMEOUT_MS"), 25_000),
    launch_args=list(_parse_launch_args(os.getenv("SCRAPER_LAUNCH_ARGS"))) if os.getenv("SCRAPER_LAUNCH_ARGS") else None,
)


def detect_platform(url: str) -> str:
    host = urlparse(url).netloc.lower()
    if "linkedin." in host:
        return "linkedin"
    if "welcometothejungle" in host or host.endswith("wttj.co"):
        return "wttj"
    raise UnsupportedPlatformError(f"Unsupported job board for host: {host}")


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "service": "scraper_api",
        "status": "running",
        "version": "0.1.0"
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}


@app.post("/scrape/offer", response_model=JobOfferData)
async def scrape_offer(request: ScrapeRequest):
    url = str(request.url)

    try:
        platform = detect_platform(url)
    except UnsupportedPlatformError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    parser = PARSER_REGISTRY[platform]

    async with BrowserSession(BROWSER_CONFIG) as page:
        try:
            payload = await parser.parse(page, url)
        except UnsupportedPlatformError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except NetworkError as exc:
            raise HTTPException(status_code=504, detail=str(exc)) from exc
        except ParsingError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:  # pragma: no cover - safety net for unexpected issues
            logger.exception("Unexpected error while scraping %s", url)
            raise HTTPException(status_code=502, detail="Unexpected error while scraping the offer.") from exc

    return JobOfferData(**payload)
