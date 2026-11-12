import json
import time
from datetime import datetime
from pathlib import Path
import pandas as pd
from sqlalchemy import text
from python.campo_real.config import settings
from python.campo_real.db import engine, ensure_tables, start_run, finish_run
from python.campo_real.http import get_json

def main():
    ensure_tables()
    run_id = start_run("OPEN_METEO_CLIMA")
    total = 0
    raw_dir = Path("data/raw/open_meteo")
    raw_dir.mkdir(parents=True, exist_ok=True)
    try:
        with engine.connect() as conn:
            plants = pd.read_sql(text("""SELECT id_usina, latitude, longitude FROM usina
                WHERE latitude IS NOT NULL AND longitude IS NOT NULL"""), conn)
        for plant in plants.itertuples(index=False):
            params = {
                "latitude": float(plant.latitude), "longitude": float(plant.longitude),
                "start_date": settings.climate_start, "end_date": settings.climate_end,
                "hourly": "temperature_2m,precipitation,wind_speed_10m,shortwave_radiation",
                "timezone": "America/Sao_Paulo"
            }
            payload = get_json(settings.open_meteo_url, params)
            (raw_dir / f"usina_{plant.id_usina}.json").write_text(
                json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
            hourly = payload.get("hourly", {})
            times = hourly.get("time", [])
            rows = []
            extracted_at = datetime.now()
            for i, stamp in enumerate(times):
                def val(key):
                    values = hourly.get(key, [])
                    return values[i] if i < len(values) else None
                rows.append({
                    "usina_id": int(plant.id_usina), "latitude": float(plant.latitude),
                    "longitude": float(plant.longitude),
                    "data_hora": pd.to_datetime(stamp).to_pydatetime(),
                    "temperatura_c": val("temperature_2m"),
                    "precipitacao_mm": val("precipitation"),
                    "vento_kmh": val("wind_speed_10m"),
                    "radiacao_wm2": val("shortwave_radiation"),
                    "extraido_em": extracted_at
                })
            if rows:
                with engine.begin() as conn:
                    conn.execute(text("""INSERT INTO raw_clima_horario
                        (usina_id,latitude,longitude,data_hora,temperatura_c,
                         precipitacao_mm,vento_kmh,radiacao_wm2,extraido_em)
                        VALUES (:usina_id,:latitude,:longitude,:data_hora,:temperatura_c,
                         :precipitacao_mm,:vento_kmh,:radiacao_wm2,:extraido_em)
                        ON DUPLICATE KEY UPDATE temperatura_c=VALUES(temperatura_c),
                         precipitacao_mm=VALUES(precipitacao_mm), vento_kmh=VALUES(vento_kmh),
                         radiacao_wm2=VALUES(radiacao_wm2), extraido_em=VALUES(extraido_em)"""), rows)
                total += len(rows)
            time.sleep(0.3)
        finish_run(run_id, total, total, "SUCESSO")
        print(f"Clima: {total} observações horárias gravadas.")
    except Exception as exc:
        finish_run(run_id, total, total, "ERRO", exc)
        raise

if __name__ == "__main__":
    main()
