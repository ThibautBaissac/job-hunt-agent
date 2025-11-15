"""Custom exceptions raised by the scraper service."""


class ScraperError(Exception):
    """Base class for scraper errors."""


class UnsupportedPlatformError(ScraperError):
    """Raised when the URL does not match any supported platform."""


class NetworkError(ScraperError):
    """Raised when the remote page cannot be reached in time."""


class ParsingError(ScraperError):
    """Raised when the scraper cannot extract mandatory fields."""


class AuthenticationError(ScraperError):
    """Raised when the platform requires authentication to view the content."""
