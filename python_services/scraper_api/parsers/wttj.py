"""Welcome to the Jungle parser."""
from __future__ import annotations

import json
import logging
import re
from typing import Iterable

from playwright.async_api import Page, TimeoutError as PlaywrightTimeoutError

from .base import BaseParser

logger = logging.getLogger(__name__)


class WttjParser(BaseParser):
    """Parser for Welcome to the Jungle job pages."""

    platform = "wttj"

    async def _extract(self, page: Page, url: str) -> dict[str, str | None]:  # noqa: ARG002
        # Wait for the job description content to be rendered
        # WTTJ is a SPA, so we need to wait for React to render the content
        try:
            await page.wait_for_selector("[data-testid='job-section-description']", timeout=10_000)
            logger.debug("WTTJ job description section found")
        except TimeoutError as exc:
            logger.warning("WTTJ job description section not found after 10s")
            # Continue anyway, fallback methods might still work

        job_payload = await self._extract_from_next_data(page)

        logger.debug("WTTJ __NEXT_DATA__ payload: %s", job_payload)

        # Extract title from page <title> tag as fallback
        # WTTJ format: "{Job Title} - {Company} - {Contract} - {Location}"
        page_title = await page.title()
        title_from_tag = None
        if page_title:
            # Extract first part before " - " separator
            parts = page_title.split(" - ")
            if parts:
                title_from_tag = parts[0].strip()

        title = self._first_non_empty(
            [
                job_payload.get("title") if job_payload else None,
                await self._first_selector_text(page, ["h1[data-testid='job-title']", "h1", "header h1"]),
                title_from_tag,
            ]
        )

        # Extract company from page <title> tag as fallback
        company_from_tag = None
        if page_title:
            parts = page_title.split(" - ")
            if len(parts) >= 2:
                company_from_tag = parts[1].strip()

        company = self._first_non_empty(
            [
                job_payload.get("company") if job_payload else None,
                await self._first_selector_text(page, ["[data-testid='company-name']", "header a[href*='companies']"]),
                company_from_tag,
            ]
        )

        location = self._first_non_empty(
            [
                job_payload.get("location") if job_payload else None,
                await self._first_selector_text(page, ["[data-testid='job-location']", "header [data-testid='job-location']", "header span"], collapse_commas=True),
            ]
        )

        description_html = self._first_non_empty(
            [
                job_payload.get("description") if job_payload else None,
                await self._first_selector_html(page, ["article", "div[data-testid='job-description']", "section"]),
            ]
        )

        description = self._html_to_text(description_html)

        logger.debug("WTTJ extracted: title=%s, company=%s, location=%s, description_length=%s",
                     title, company, location, len(description) if description else 0)

        return {
            "title": title,
            "company": company,
            "location": location,
            "description": description,
            "platform": self.platform,
        }

    async def _extract_from_next_data(self, page: Page) -> dict[str, str | None] | None:
        """Extract job data from WTTJ's __INITIAL_DATA__ or __NEXT_DATA__ script tag by parsing HTML."""
        # Get the page HTML
        html_content = await page.content()

        # Try to extract __INITIAL_DATA__ from script tag (new WTTJ format)
        # Match the entire line: window.__INITIAL_DATA__ = "..." up to the closing quote
        initial_data_match = re.search(r'window\.__INITIAL_DATA__\s*=\s*"((?:[^"\\]|\\.)*)"\s*(?:;|$)', html_content, re.MULTILINE)
        if initial_data_match:
            try:
                # The data is JSON-stringified: it's a JSON string containing another JSON string
                # First, extract the raw escaped content
                escaped_content = initial_data_match.group(1)

                # Decode it as a JSON string (this handles \\u002F, \", \\n, etc.)
                json_str = json.loads(f'"{escaped_content}"')

                # Now parse the actual JSON data
                data = json.loads(json_str)

                logger.debug("Successfully parsed __INITIAL_DATA__")

                # Navigate the data structure to find job information
                queries = data.get("queries", [])
                for query in queries:
                    job_data = query.get("state", {}).get("data", {})
                    if job_data and job_data.get("name"):
                        office = job_data.get("office", {})
                        city = office.get("city")
                        country = office.get("country_code")

                        location = None
                        if city and country:
                            location = f"{city}, {country}"
                        elif city:
                            location = city
                        elif country:
                            location = country

                        # WTTJ uses 'profile' field for job description
                        description = job_data.get("profile") or job_data.get("description")

                        org_data = job_data.get("organization", {})
                        company = org_data.get("name") if isinstance(org_data, dict) else None

                        return {
                            "title": job_data.get("name"),
                            "company": company,
                            "location": location,
                            "description": description,
                        }
            except (json.JSONDecodeError, AttributeError, KeyError) as exc:
                logger.warning("Failed to parse __INITIAL_DATA__: %s", exc)

        # Fallback: Try __NEXT_DATA__ (old format - unlikely to exist now)
        next_data_match = re.search(r'window\.__NEXT_DATA__\s*=\s*({.+?});', html_content, re.DOTALL)
        if next_data_match:
            try:
                data = json.loads(next_data_match.group(1))
                job = data.get("props", {}).get("pageProps", {}).get("job", {})
                if job:
                    office = job.get("office", {})
                    address = office.get("address", {})
                    city = address.get("city")
                    country = address.get("country")

                    location = None
                    if city and country:
                        location = f"{city}, {country}"
                    elif city:
                        location = city
                    elif country:
                        location = country

                    company_data = job.get("company", {})

                    return {
                        "title": job.get("title"),
                        "company": company_data.get("name") if isinstance(company_data, dict) else None,
                        "location": location,
                        "description": job.get("description"),
                    }
            except (json.JSONDecodeError, AttributeError, KeyError) as exc:
                logger.warning("Failed to parse __NEXT_DATA__: %s", exc)

        return None

    async def _first_selector_text(
        self,
        page: Page,
        selectors: Iterable[str],
        *,
        collapse_commas: bool = False,
    ) -> str | None:
        for selector in selectors:
            locator = page.locator(selector)
            try:
                if await locator.count() == 0:
                    continue
                value = await locator.first.inner_text(timeout=1_000)
            except PlaywrightTimeoutError:
                continue
            if not value:
                continue
            value = value.strip()
            if not value:
                continue
            if collapse_commas:
                value = value.replace("\n", ", ")
            return value
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
