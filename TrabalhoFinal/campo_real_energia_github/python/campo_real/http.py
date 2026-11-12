import time
import requests
from .config import settings

def get_json(url, params=None):
    last_error = None
    for attempt in range(settings.retries):
        try:
            response = requests.get(url, params=params, timeout=settings.timeout)
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict):
                raise ValueError("A resposta não é um objeto JSON.")
            return payload
        except (requests.RequestException, ValueError) as exc:
            last_error = exc
            if attempt + 1 < settings.retries:
                time.sleep(2 ** attempt)
    raise RuntimeError(f"Falha após {settings.retries} tentativas: {last_error}")
