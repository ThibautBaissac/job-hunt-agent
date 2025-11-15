"""LinkedIn job offer parser."""
from __future__ import annotations

from typing import Iterable

from playwright.async_api import Page, TimeoutError as PlaywrightTimeoutError

from .base import BaseParser


class LinkedinParser(BaseParser):
    """Parser for LinkedIn job pages."""

    platform = "linkedin"

    async def _extract(self, page: Page, url: str) -> dict[str, str | None]:  # noqa: ARG002
        await page.wait_for_timeout(800)
        job_from_state = await self._extract_from_state(page)

        title = self._first_non_empty(
            [
                job_from_state.get("title") if job_from_state else None,
                await self._first_selector_text(page, [
                    "h1.top-card-layout__title",
                    "h1.jobs-unified-top-card__job-title",
                    "main h1",
                ]),
            ]
        )

        company = self._first_non_empty(
            [
                job_from_state.get("company") if job_from_state else None,
                await self._first_selector_text(page, [
                    "a.topcard__org-name-link",
                    "a.jobs-unified-top-card__company-name",
                    "span.topcard__flavor",
                    "span.jobs-unified-top-card__company-name",
                ]),
            ]
        )

        location = self._first_non_empty(
            [
                job_from_state.get("location") if job_from_state else None,
                await self._first_selector_text(page, [
                    "span.topcard__flavor--bullet",
                    "span.jobs-unified-top-card__bullet",
                ]),
            ]
        )

        description_html = self._first_non_empty(
            [
                job_from_state.get("description") if job_from_state else None,
                await self._first_selector_html(page, [
                    "div.description__text",
                    "div.jobs-description__content",
                    "section.jobs-description",
                ]),
            ]
        )

        description = self._html_to_text(description_html)

        return {
            "title": title,
            "company": company,
            "location": location,
            "description": description,
            "platform": self.platform,
        }

    async def _extract_from_state(self, page: Page) -> dict[str, str | None] | None:
        payload = await page.evaluate(
            """
            () => {
                const state = window.__PRELOADED_STATE__;
                if (!state || !state.jobPostings) {
                    return null;
                }
                const ids = Object.keys(state.jobPostings);
                if (!ids.length) {
                    return null;
                }
                const job = state.jobPostings[ids[0]];
                if (!job) {
                    return null;
                }
                const description = job.description?.text || job.description?.rawText || null;
                return {
                    title: job.title || null,
                    company: job.companyName || job.formattedCompanyName || null,
                    location: job.formattedLocation || job.formattedLocationName || null,
                    description,
                };
            }
            """
        )
        if not payload:
            return None
        return {key: value for key, value in payload.items() if value}

    async def _first_selector_text(self, page: Page, selectors: Iterable[str]) -> str | None:
        for selector in selectors:
            locator = page.locator(selector)
            try:
                if await locator.count() == 0:
                    continue
                value = await locator.first.inner_text(timeout=1_000)
            except PlaywrightTimeoutError:
                continue
            if value and value.strip():
                return value.strip()
        return None

    async def _first_selector_html(self, page: Page, selectors: Iterable[str]) -> str | None:
        for selector in selectors:
            locator = page.locator(selector)
            try:
                if await locator.count() == 0:
                    continue
                value = await locator.first.inner_html(timeout=1_000)
            except PlaywrightTimeoutError:
                continue
            if value and value.strip():
                return value
        return None
