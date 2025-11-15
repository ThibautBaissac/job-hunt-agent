"""Parsers package for platform-specific scraping logic."""

from .linkedin import LinkedinParser
from .wttj import WttjParser

__all__ = [
	"LinkedinParser",
	"WttjParser",
]
