from dataclasses import dataclass
import os
from dotenv import load_dotenv

load_dotenv()

@dataclass(frozen=True)
class Settings:
    db_host: str = os.getenv("DB_HOST", "localhost")
    db_port: int = int(os.getenv("DB_PORT", "3306"))
    db_name: str = os.getenv("DB_NAME", "campo_real_energia")
    db_user: str = os.getenv("DB_USER", "root")
    db_password: str = os.getenv("DB_PASSWORD", "")
    ccee_api_url: str = os.getenv("CCEE_API_URL", "https://dadosabertos.ccee.org.br/api/3/action/datastore_search")
    ccee_2025: str = os.getenv("CCEE_RESOURCE_ID_2025", "")
    ccee_2026: str = os.getenv("CCEE_RESOURCE_ID_2026", "")
    page_size: int = int(os.getenv("CCEE_PAGE_SIZE", "5000"))
    timeout: int = int(os.getenv("REQUEST_TIMEOUT", "60"))
    retries: int = int(os.getenv("REQUEST_RETRIES", "3"))
    open_meteo_url: str = os.getenv("OPEN_METEO_URL", "https://archive-api.open-meteo.com/v1/archive")
    climate_start: str = os.getenv("OPEN_METEO_START", "2025-01-01")
    climate_end: str = os.getenv("OPEN_METEO_END", "2025-12-31")

settings = Settings()

def database_url():
    from urllib.parse import quote_plus
    return (f"mysql+pymysql://{settings.db_user}:{quote_plus(settings.db_password)}"
            f"@{settings.db_host}:{settings.db_port}/{settings.db_name}?charset=utf8mb4")
