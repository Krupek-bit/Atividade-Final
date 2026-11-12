CREATE DATABASE IF NOT EXISTS dw_campo_real;
USE dw_campo_real;

-- Grão: uma linha por hora do calendário.
CREATE TABLE IF NOT EXISTS dim_tempo (
 tempo_sk BIGINT AUTO_INCREMENT PRIMARY KEY, data_hora DATETIME NOT NULL UNIQUE,
 data DATE NOT NULL, ano SMALLINT NOT NULL, mes TINYINT NOT NULL, dia TINYINT NOT NULL,
 hora TINYINT NOT NULL, dia_semana TINYINT NOT NULL, nome_dia VARCHAR(15) NOT NULL,
 nome_mes VARCHAR(15) NOT NULL, dia_util BOOLEAN NOT NULL, feriado BOOLEAN NOT NULL DEFAULT FALSE,
 trimestre TINYINT NOT NULL, estacao_ano VARCHAR(15)
);

-- SCD Tipo 2: preservar versões históricas de atributos da usina.
CREATE TABLE IF NOT EXISTS dim_usina (
 usina_sk BIGINT AUTO_INCREMENT PRIMARY KEY, usina_id_origem BIGINT NOT NULL,
 nome_usina VARCHAR(150), fonte_energia VARCHAR(80), submercado VARCHAR(10),
 uf CHAR(2), municipio VARCHAR(100), potencia_mw DECIMAL(14,4),
 latitude DECIMAL(10,6), longitude DECIMAL(10,6),
 valido_desde DATETIME NOT NULL, valido_ate DATETIME,
 registro_atual BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE KEY uq_usina_versao (usina_id_origem,valido_desde),
 INDEX idx_usina_atual (usina_id_origem,registro_atual)
);

CREATE TABLE IF NOT EXISTS dim_submercado (
 submercado_sk INT AUTO_INCREMENT PRIMARY KEY, codigo VARCHAR(10) NOT NULL UNIQUE,
 descricao VARCHAR(80)
);
CREATE TABLE IF NOT EXISTS dim_fonte_energia (
 fonte_sk INT AUTO_INCREMENT PRIMARY KEY, descricao VARCHAR(80) NOT NULL UNIQUE,
 renovavel BOOLEAN, intermitente BOOLEAN
);

-- Chaves substitutas 0 reservadas para membro desconhecido.
INSERT IGNORE INTO dim_submercado (submercado_sk,codigo,descricao)
VALUES (0,'UNK','Desconhecido');
INSERT IGNORE INTO dim_fonte_energia (fonte_sk,descricao)
VALUES (0,'Desconhecida');

-- Grão: uma linha por usina e hora de medição.
CREATE TABLE IF NOT EXISTS fato_geracao (
 geracao_sk BIGINT AUTO_INCREMENT PRIMARY KEY, tempo_sk BIGINT NOT NULL,
 usina_sk BIGINT NOT NULL, submercado_sk INT NOT NULL, fonte_sk INT NOT NULL,
 geracao_mwh DECIMAL(16,6), disponibilidade_pct DECIMAL(8,4),
 energia_indisponivel_mwh DECIMAL(16,6), recebido_em DATETIME, origem_id BIGINT,
 UNIQUE KEY uq_geracao (tempo_sk,usina_sk,origem_id),
 FOREIGN KEY (tempo_sk) REFERENCES dim_tempo(tempo_sk),
 FOREIGN KEY (usina_sk) REFERENCES dim_usina(usina_sk),
 FOREIGN KEY (submercado_sk) REFERENCES dim_submercado(submercado_sk),
 FOREIGN KEY (fonte_sk) REFERENCES dim_fonte_energia(fonte_sk)
);

-- Grão: uma linha por submercado, hora e versão do preço.
CREATE TABLE IF NOT EXISTS fato_pld (
 pld_sk BIGINT AUTO_INCREMENT PRIMARY KEY, tempo_sk BIGINT NOT NULL,
 submercado_sk INT NOT NULL, pld_mwh DECIMAL(16,6) NOT NULL,
 versao_preco VARCHAR(40), origem VARCHAR(80) NOT NULL DEFAULT 'CCEE',
 UNIQUE KEY uq_pld (tempo_sk,submercado_sk,versao_preco),
 FOREIGN KEY (tempo_sk) REFERENCES dim_tempo(tempo_sk),
 FOREIGN KEY (submercado_sk) REFERENCES dim_submercado(submercado_sk)
);

-- Grão: uma linha por usina e hora de observação meteorológica.
CREATE TABLE IF NOT EXISTS fato_clima (
 clima_sk BIGINT AUTO_INCREMENT PRIMARY KEY, tempo_sk BIGINT NOT NULL,
 usina_sk BIGINT NOT NULL, temperatura_c DECIMAL(8,3),
 precipitacao_mm DECIMAL(10,3), vento_kmh DECIMAL(10,3), radiacao_wm2 DECIMAL(10,3),
 UNIQUE KEY uq_clima (tempo_sk,usina_sk),
 FOREIGN KEY (tempo_sk) REFERENCES dim_tempo(tempo_sk),
 FOREIGN KEY (usina_sk) REFERENCES dim_usina(usina_sk)
);

-- Matriz de barramento:
-- Geração horária: Tempo, Usina, Submercado, Fonte.
-- PLD horário: Tempo, Submercado.
-- Clima horário: Tempo, Usina.
