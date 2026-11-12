from python.campo_real.db import ensure_tables
from python.campo_real.quality import run_checks

if __name__ == "__main__":
    ensure_tables()
    run_checks()
