import json
from datetime import datetime
from pathlib import Path
from sqlalchemy import text
from python.campo_real.config import settings
from python.campo_real.db import engine, ensure_tables, start_run, finish_run
from python.campo_real.http import get_json

def extract_year(year, resource_id):
    if not resource_id:
        raise ValueError(f"Preencha CCEE_RESOURCE_ID_{year} no .env.")
    run_id = start_run(f"CCEE_PLD_{year}")
    offset = read_count = written_count = 0
    raw_dir = Path("data/raw/ccee")
    raw_dir.mkdir(parents=True, exist_ok=True)
    try:
        while True:
            params = {"resource_id": resource_id, "limit": settings.page_size, "offset": offset}
            payload = get_json(settings.ccee_api_url, params)
            if payload.get("success") is not True:
                raise RuntimeError(f"Falha da API CKAN: {payload}")
            records = payload.get("result", {}).get("records", [])
            if not records:
                break
            extracted_at = datetime.now()
            (raw_dir / f"pld_{year}_offset_{offset}.json").write_text(
                json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
            rows = [{"ano": year, "resource_id": resource_id,
                     "extraido_em": extracted_at,
                     "registro_json": json.dumps(record, ensure_ascii=False)}
                    for record in records]
            with engine.begin() as conn:
                conn.execute(text("""INSERT INTO raw_pld_ccee
                    (ano,resource_id,extraido_em,registro_json)
                    VALUES (:ano,:resource_id,:extraido_em,:registro_json)"""), rows)
            read_count += len(records)
            written_count += len(rows)
            offset += len(records)
            if len(records) < settings.page_size:
                break
        finish_run(run_id, read_count, written_count, "SUCESSO")
        print(f"PLD {year}: {written_count} registros gravados.")
    except Exception as exc:
        finish_run(run_id, read_count, written_count, "ERRO", exc)
        raise

def main():
    ensure_tables()
    extract_year(2025, settings.ccee_2025)
    extract_year(2026, settings.ccee_2026)

if __name__ == "__main__":
    main()
