# main.py
from dotenv import load_dotenv
import os

load_dotenv(dotenv_path="../../.env")

AGENT_API_URL = os.getenv("AGENT_API_URL")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
