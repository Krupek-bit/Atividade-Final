from sqlalchemy import create_engine, text
from .config import database_url

engine = create_engine(database_url(), pool_pre_ping=True, future=True)

def ensure_tables():
    statements = [
        """CREATE TABLE IF NOT EXISTS carga_execucao (
            id BIGINT AUTO_INCREMENT PRIMARY KEY, fonte VARCHAR(80) NOT NULL,
            inicio DATETIME NOT NULL, fim DATETIME NULL,
            linhas_lidas BIGINT NOT NULL DEFAULT 0, linhas_gravadas BIGINT NOT NULL DEFAULT 0,
            status VARCHAR(20) NOT NULL, erro TEXT NULL)""",
        """CREATE TABLE IF NOT EXISTS raw_pld_ccee (
            id BIGINT AUTO_INCREMENT PRIMARY KEY, ano SMALLINT NOT NULL,
            resource_id VARCHAR(100) NOT NULL, extraido_em DATETIME NOT NULL,
            registro_json JSON NOT NULL, INDEX idx_raw_pld_ano (ano))""",
        """CREATE TABLE IF NOT EXISTS raw_clima_horario (
            id BIGINT AUTO_INCREMENT PRIMARY KEY, usina_id BIGINT NOT NULL,
            latitude DECIMAL(10,6) NOT NULL, longitude DECIMAL(10,6) NOT NULL,
            data_hora DATETIME NOT NULL, temperatura_c DECIMAL(8,3) NULL,
            precipitacao_mm DECIMAL(10,3) NULL, vento_kmh DECIMAL(10,3) NULL,
            radiacao_wm2 DECIMAL(10,3) NULL, extraido_em DATETIME NOT NULL,
            UNIQUE KEY uq_clima_usina_hora (usina_id, data_hora))""",
        """CREATE TABLE IF NOT EXISTS qualidade_metricas (
            id BIGINT AUTO_INCREMENT PRIMARY KEY, regra VARCHAR(120) NOT NULL,
            dimensao VARCHAR(40) NOT NULL, tabela_avaliada VARCHAR(120) NOT NULL,
            registros_avaliados BIGINT NOT NULL, registros_com_falha BIGINT NOT NULL,
            percentual_falha DECIMAL(8,4) NOT NULL, executado_em DATETIME NOT NULL,
            observacao TEXT NULL)"""
    ]
    with engine.begin() as conn:
        for sql in statements:
            conn.execute(text(sql))

def start_run(source):
    with engine.begin() as conn:
        result = conn.execute(text(
            "INSERT INTO carga_execucao (fonte,inicio,status) VALUES (:f,NOW(),'EXECUTANDO')"
        ), {"f": source})
        return int(result.lastrowid)

def finish_run(run_id, read, written, status, error=None):
    with engine.begin() as conn:
        conn.execute(text("""UPDATE carga_execucao SET fim=NOW(), linhas_lidas=:r,
            linhas_gravadas=:w, status=:s, erro=:e WHERE id=:id"""),
            {"r": read, "w": written, "s": status,
             "e": str(error)[:60000] if error else None, "id": run_id})
