"""Base helpers for platform-specific parsers."""
from __future__ import annotations

import re
from abc import ABC, abstractmethod
from typing import Iterable

from bs4 import BeautifulSoup
from playwright.async_api import (
    Page,
    TimeoutError as PlaywrightTimeoutError,
    Error as PlaywrightError,
)

from ..core.exceptions import NetworkError, ParsingError


class BaseParser(ABC):
    """Abstract parser handling the common loading flow."""

    platform: str
    page_timeout_ms: int = 25_000

    async def parse(self, page: Page, url: str) -> dict[str, str | None]:  # noqa: D401
        """Load the page and return a dict containing the scraped fields."""
        await self._load(page, url)
        data = await self._extract(page, url)
        self._validate(data)
        return data

    async def _load(self, page: Page, url: str) -> None:
        try:
            await page.goto(url, wait_until="domcontentloaded")
            try:
                await page.wait_for_load_state("networkidle", timeout=5_000)
            except PlaywrightTimeoutError:
                # Network idle is best-effort; continue with parsed DOM even if some assets are pending.
                pass
        except PlaywrightTimeoutError as exc:  # pragma: no cover - network-dependent
            raise NetworkError(f"Timeout while loading {url}") from exc
        except PlaywrightError as exc:  # pragma: no cover - browser-specific crashes
            raise NetworkError(f"Échec du chargement de la page : {exc}") from exc

    @abstractmethod
    async def _extract(self, page: Page, url: str) -> dict[str, str | None]:
        """Extract the relevant information from the DOM."""

    def _validate(self, data: dict[str, str | None]) -> None:
        import logging
        logger = logging.getLogger(__name__)

        missing = [field for field in ("title", "company", "description") if not self._has_text(data.get(field))]
        if missing:
            logger.warning(
                "Parser validation failed for platform '%s'. Missing fields: %s. Extracted data: %s",
                self.platform,
                missing,
                {k: (v[:100] + "..." if v and len(v) > 100 else v) for k, v in data.items()}
            )
            raise ParsingError(f"Missing mandatory fields: {', '.join(missing)}")

    @staticmethod
    def _collapse(text: str | None) -> str | None:
        if not text:
            return None
        collapsed = re.sub(r"\s+", " ", text).strip()
        return collapsed or None

    def _first_non_empty(self, values: Iterable[str | None]) -> str | None:
        for value in values:
            collapsed = self._collapse(value)
            if collapsed:
                return collapsed
        return None

    @staticmethod
    def _html_to_text(html: str | None) -> str | None:
        if not html:
            return None
        soup = BeautifulSoup(html, "lxml")
        text = soup.get_text(separator="\n")
        return text.strip() if text else None

    @staticmethod
    def _has_text(value: str | None) -> bool:
        return bool(value and value.strip())
