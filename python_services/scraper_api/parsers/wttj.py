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
        except (TimeoutError, PlaywrightTimeoutError) as exc:
            logger.warning("WTTJ job description section not found after 10s, continuing anyway...")
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

                        # Extract organization data
                        org_data = job_data.get("organization", {})
                        company = org_data.get("name") if isinstance(org_data, dict) else None
                        company_description = org_data.get("description") if isinstance(org_data, dict) else None

                        # Build comprehensive description combining all sections
                        description_parts = []

                        # 1. Descriptif du poste (Job description)
                        job_description = job_data.get("description")
                        if job_description:
                            description_parts.append("=== DESCRIPTIF DU POSTE ===\n" + job_description)

                        # 2. Profil recherché (Profile)
                        profile = job_data.get("profile")
                        if profile:
                            description_parts.append("=== PROFIL RECHERCHÉ ===\n" + profile)

                        # 3. Qui sont-ils ? (Company description)
                        if company_description:
                            description_parts.append("=== L'ENTREPRISE ===\n" + company_description)

                        # 4. Déroulement des entretiens (Recruitment process)
                        recruitment_process = job_data.get("recruitment_process")
                        if recruitment_process:
                            description_parts.append("=== DÉROULEMENT DES ENTRETIENS ===\n" + recruitment_process)

                        # 5. Les conditions (Job conditions)
                        conditions = []

                        # Contract type
                        contract_type_names = job_data.get("contract_type_names")
                        if contract_type_names:
                            if isinstance(contract_type_names, list):
                                conditions.append(f"Contrat : {', '.join(contract_type_names)}")
                            else:
                                conditions.append(f"Contrat : {contract_type_names}")

                        # Experience level
                        experience_name = job_data.get("experience_level_minimum_name")
                        if experience_name:
                            conditions.append(f"Expérience : {experience_name}")

                        # Remote work
                        remote_name = job_data.get("remote_name")
                        if remote_name:
                            conditions.append(f"Télétravail : {remote_name}")

                        # Salary (WTTJ API returns values in thousands already, e.g., 57 = 57K€)
                        salary_min = job_data.get("salary_min")
                        salary_max = job_data.get("salary_max")
                        salary_currency = job_data.get("salary_currency", "€")
                        salary_period = job_data.get("salary_period")

                        if salary_min or salary_max:
                            salary_str = "Salaire : "
                            if salary_min and salary_max:
                                # If values are < 1000, they're already in K format (57 = 57K)
                                # If values are >= 1000, they need to be divided (57000 = 57K)
                                if salary_min >= 1000 and salary_max >= 1000:
                                    min_k = f"{int(salary_min / 1000)}K"
                                    max_k = f"{int(salary_max / 1000)}K"
                                    salary_str += f"{min_k} à {max_k} {salary_currency}"
                                else:
                                    salary_str += f"{int(salary_min)}K à {int(salary_max)}K {salary_currency}"
                            elif salary_min:
                                if salary_min >= 1000:
                                    min_k = f"{int(salary_min / 1000)}K"
                                    salary_str += f"à partir de {min_k} {salary_currency}"
                                else:
                                    salary_str += f"à partir de {int(salary_min)}K {salary_currency}"
                            elif salary_max:
                                if salary_max >= 1000:
                                    max_k = f"{int(salary_max / 1000)}K"
                                    salary_str += f"jusqu'à {max_k} {salary_currency}"
                                else:
                                    salary_str += f"jusqu'à {int(salary_max)}K {salary_currency}"

                            if salary_period:
                                salary_str += f" / {salary_period}"

                            conditions.append(salary_str)

                        if conditions:
                            description_parts.append("=== LES CONDITIONS ===\n" + "\n".join(conditions))

                        # Combine all sections
                        full_description = "\n\n".join(description_parts) if description_parts else None

                        return {
                            "title": job_data.get("name"),
                            "company": company,
                            "location": location,
                            "description": full_description,
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
