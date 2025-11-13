"""
Agent API - FastAPI service for AI-powered job application assistance.

Handles:
- Job application analysis and preparation
- CV matching and suggestions
- Email and cover letter generation
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

# Load environment variables from root .env
load_dotenv(dotenv_path="../../.env")

app = FastAPI(
    title="Job Hunt Agent API",
    description="AI-powered job application assistance using LangChain",
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


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "service": "agent_api",
        "status": "running",
        "version": "0.1.0"
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}


# TODO: Add routers for:
# - /agent/job_application (POST)
# - /agent/cv_analysis (POST)
# These will be implemented according to the architecture docs
