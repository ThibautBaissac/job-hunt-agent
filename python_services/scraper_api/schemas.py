"""Pydantic schemas used by the scraper API."""
from pydantic import BaseModel, HttpUrl


class ScrapeRequest(BaseModel):
    """Payload received when the Rails app requests scraping."""

    url: HttpUrl


class JobOfferData(BaseModel):
    """Structured representation of the scraped job offer."""

    title: str
    company: str
    location: str | None = None
    description: str
    platform: str
