from datetime import datetime
from pathlib import Path
import pandas as pd
from sqlalchemy import text
from .db import engine

def save_metric(rule, dimension, table, evaluated, failed, note=None):
    percent = (failed / evaluated * 100) if evaluated else 0
    with engine.begin() as conn:
        conn.execute(text("""INSERT INTO qualidade_metricas
            (regra,dimensao,tabela_avaliada,registros_avaliados,
             registros_com_falha,percentual_falha,executado_em,observacao)
            VALUES (:r,:d,:t,:a,:f,:p,:dt,:n)"""),
            {"r": rule, "d": dimension, "t": table, "a": evaluated,
             "f": int(failed), "p": percent, "dt": datetime.now(), "n": note})

def profile(table):
    # As tabelas abaixo são nomes fixos do projeto, não parâmetros externos.
    with engine.connect() as conn:
        frame = pd.read_sql(text(f"SELECT * FROM {table}"), conn)
    report = pd.DataFrame({
        "tipo": frame.dtypes.astype(str),
        "nulos": frame.isna().sum(),
        "distintos": frame.nunique(dropna=True)
    })
    Path("data/processed").mkdir(parents=True, exist_ok=True)
    report.to_csv(f"data/processed/profiling_{table}.csv", encoding="utf-8-sig")
    return frame

def run_checks():
    plants = profile("usina")
    generation = profile("medicao_geracao")

    missing = generation[["id_usina", "data_hora"]].isna().any(axis=1).sum()
    save_metric("campos_obrigatorios_preenchidos", "completude",
                "medicao_geracao", len(generation), missing)

    duplicated = generation.duplicated(["id_usina", "data_hora"], keep=False).sum()
    save_metric("usina_hora_duplicada", "unicidade",
                "medicao_geracao", len(generation), duplicated)

    invalid = 0
    if "energia_mwh" in generation:
        invalid += (generation["energia_mwh"] < 0).sum()
    if "disponibilidade_mw" in generation:
        invalid += (generation["disponibilidade_mw"] < 0).sum()
        invalid += (generation["disponibilidade_mw"] > 100).sum()
    save_metric("valores_fora_da_faixa", "validade",
                "medicao_geracao", len(generation), invalid)

    known_ids = set(plants["id"].dropna())
    orphan = (~generation["id_usina"].isin(known_ids)).sum()
    save_metric("usina_referenciada_existe", "integridade_referencial",
                "medicao_geracao", len(generation), orphan)

    late = 0
    if {"data_hora", "recebido_em"}.issubset(generation.columns):
        measured = pd.to_datetime(generation["data_hora"], errors="coerce")
        received = pd.to_datetime(generation["recebido_em"], errors="coerce")
        late = ((received - measured).dt.total_seconds() > 3600).sum()
    save_metric("recebimento_com_atraso_maior_1h", "atualidade",
                "medicao_geracao", len(generation), late)
    print("Profiling e regras iniciais finalizados; confira qualidade_metricas e data/processed.")

if __name__ == "__main__":
    run_checks()
