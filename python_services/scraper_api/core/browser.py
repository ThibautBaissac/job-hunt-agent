"""Utilities to bootstrap a Playwright browser session."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from playwright.async_api import async_playwright, Browser, BrowserContext, Page


@dataclass
class BrowserConfig:
    """Configuration for Playwright browser."""

    headless: bool = True
    page_timeout: int = 30_000
    launch_args: list[str] | None = None
    user_agent: str | None = None

    def get_launch_args(self) -> list[str]:
        """Get browser launch arguments with safe defaults for containerized environments."""
        if self.launch_args:
            return self.launch_args

        return [
            # Security: Required for running as root in containers
            "--no-sandbox",
            "--disable-setuid-sandbox",
            # Memory: Use disk instead of /dev/shm for shared memory
            "--disable-dev-shm-usage",
            # Performance: Disable unnecessary features
            "--disable-gpu",
            "--disable-software-rasterizer",
            "--disable-extensions",
            "--disable-background-networking",
            "--disable-default-apps",
            "--disable-sync",
            # Stability: Single process mode for constrained environments
            "--single-process",
            "--no-zygote",
        ]


class BrowserSession:
    """Async context manager returning a fresh Playwright page."""

    def __init__(self, config: BrowserConfig):
        self._config = config
        self._playwright = None
        self._browser: Browser | None = None
        self._context: BrowserContext | None = None
        self._page: Page | None = None

    async def __aenter__(self) -> Page:
        self._playwright = await async_playwright().start()
        self._browser = await self._playwright.chromium.launch(
            headless=self._config.headless,
            args=self._config.get_launch_args(),
        )
        context_kwargs: dict[str, Any] = {
            "locale": "fr-FR",
            "viewport": {
                "width": 1280,
                "height": 720,
            },
        }
        if self._config.user_agent:
            context_kwargs["user_agent"] = self._config.user_agent
        self._context = await self._browser.new_context(**context_kwargs)

        # Block only heavy resources (images/media) to improve performance
        # Keep CSS/fonts/scripts to avoid bot detection
        async def route_handler(route):
            if route.request.resource_type in ("image", "media"):
                await route.abort()
            else:
                await route.continue_()

        await self._context.route("**/*", route_handler)

        self._page = await self._context.new_page()
        self._page.set_default_timeout(self._config.page_timeout)

        # Anti-bot detection: inject navigator.webdriver override
        await self._page.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });
        """)

        return self._page

    async def __aexit__(self, exc_type, exc, tb) -> None:
        try:
            if self._context is not None:
                await self._context.close()
            if self._browser is not None:
                await self._browser.close()
        finally:
            if self._playwright is not None:
                await self._playwright.stop()
