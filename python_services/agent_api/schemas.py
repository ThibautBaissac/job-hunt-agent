"""Pydantic schemas for the Agent API."""
from typing import List, Optional
from pydantic import BaseModel, Field


class JobOfferPayload(BaseModel):
    """Incoming job offer fields provided by the Rails application."""

    id: Optional[int] = Field(default=None)
    title: Optional[str] = Field(default=None)
    company_name: Optional[str] = Field(default=None, alias="companyName")
    location: Optional[str] = Field(default=None)
    description: Optional[str] = Field(default=None)

    class Config:
        populate_by_name = True


class CvPayload(BaseModel):
    """Optional CV data attached to the analysis request."""

    id: Optional[int] = Field(default=None)
    content: Optional[str] = Field(default=None)
    language: Optional[str] = Field(default=None)


class ProfilePayload(BaseModel):
    """Profile context for the candidate."""

    id: Optional[int] = Field(default=None)
    summary: Optional[str] = Field(default=None)
    experience_level: Optional[str] = Field(default=None, alias="experienceLevel")

    class Config:
        populate_by_name = True


class TemplatePayload(BaseModel):
    """Email or cover letter template provided by the user."""

    id: Optional[int] = Field(default=None)
    name: Optional[str] = Field(default=None)
    body: Optional[str] = Field(default=None)


class OfferAnalysisRequest(BaseModel):
    """Complete payload received by the offer analysis endpoint."""

    job_offer: JobOfferPayload = Field(alias="job_offer")
    cv: Optional[CvPayload] = None
    profile: Optional[ProfilePayload] = None
    template: Optional[TemplatePayload] = None

    class Config:
        populate_by_name = True


class OfferAnalysisData(BaseModel):
    """Structured analysis results returned to the Rails application."""

    summary: str = Field(default="")
    tech_stack: List[str] = Field(default_factory=list)
    keywords: List[str] = Field(default_factory=list)
    seniority_level: str = Field(default="")


class OfferAnalysisResponse(BaseModel):
    """Top-level response envelope for the offer analysis endpoint."""

    data: OfferAnalysisData
