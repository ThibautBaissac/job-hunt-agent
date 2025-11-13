"""
Scraper API - FastAPI service for web scraping job offers.

Handles:
- Scraping job offers from various platforms (LinkedIn, WelcomeToTheJungle, etc.)
- Using Playwright for browser automation
- Parsing and extracting structured data
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl
from dotenv import load_dotenv
import os

# Load environment variables from root .env
load_dotenv(dotenv_path="../../.env")

app = FastAPI(
    title="Job Hunt Scraper API",
    description="Web scraping service for job offers using Playwright",
    version="0.1.0"
)

# CORS middleware for Rails communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ScrapeRequest(BaseModel):
    """Request model for scraping a job offer."""
    url: HttpUrl


class JobOfferData(BaseModel):
    """Response model for scraped job offer data."""
    title: str
    company: str
    location: str
    description: str
    platform: str


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
    """
    Scrape a job offer from the provided URL.

    Supports:
    - LinkedIn
    - WelcomeToTheJungle

    TODO: Implement Playwright-based scraping logic with platform-specific parsers.
    """
    raise HTTPException(
        status_code=501,
        detail="Scraping functionality not yet implemented. Coming soon."
    )
