/* =====================================================================
   CAMPO REAL ENERGIA  -  Banco de dados de origem (MySQL 8.0+)
   ---------------------------------------------------------------------
   Aula: tabelas operacionais que servirão de FONTE para o star schema.

   O que este script cria:
     1. Banco campo_real_energia
     2. Tabelas de cadastro: submercado, fonte_energia, usina, feriado_nacional
     3. Tabela de operação:  medicao_geracao (geração horária FAKE por usina)
                             parada_usina   (manutenções e falhas FAKE)
     4. Preço spot REAL:     stg_pld_horario (cópia crua do CSV da CCEE)
                             pld_horario     (PLD tratado)
     5. Controle:            log_carga
     6. Passo 5: problemas de qualidade inseridos de propósito, como
        acontece em sistemas reais. Cabe a vocês encontrá-los.

   Observação para os alunos: aqui NÃO existe star schema. Estas são as
   tabelas de onde vocês vão extrair dados para montar dimensões e fatos.
   Antes de modelar, respondam: qual é o grão de cada tabela? Quais são
   as chaves naturais? O que vira dimensão e o que vira fato?

   Período dos dados: 01/01/2025 a 31/12/2025, horário de Brasília
   (o Brasil não tem horário de verão desde 2019).

   Fonte do PLD: CCEE - Dados Abertos, conjunto PLD_HORARIO
   https://dadosabertos.ccee.org.br/dataset/pld_horario
   Licença CC-BY 4.0 (citar a CCEE como fonte).
   ===================================================================== */


/* =====================================================================
   PASSO 0 - Criar o banco
   ATENÇÃO: o DROP apaga tudo. Rodar o script inteiro de novo recria
   o banco do zero com os mesmos dados (os dados fake são determinísticos).
   ===================================================================== */
DROP DATABASE IF EXISTS campo_real_energia;

CREATE DATABASE campo_real_energia
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE campo_real_energia;


/* =====================================================================
   PASSO 1 - Tabelas de cadastro
   ===================================================================== */

-- 1.1 Submercados do SIN (chave natural = código usado pela CCEE)
CREATE TABLE submercado (
    cod_submercado  CHAR(2)      NOT NULL,
    nome            VARCHAR(40)  NOT NULL,
    regioes         VARCHAR(80)  NOT NULL,
    PRIMARY KEY (cod_submercado)
);

INSERT INTO submercado (cod_submercado, nome, regioes) VALUES
  ('SE', 'Sudeste/Centro-Oeste', 'Sudeste e Centro-Oeste'),
  ('S',  'Sul',                  'Sul'),
  ('NE', 'Nordeste',             'Nordeste'),
  ('N',  'Norte',                'Norte');


-- 1.2 Fontes de energia
CREATE TABLE fonte_energia (
    id_fonte        TINYINT      NOT NULL AUTO_INCREMENT,
    cod_fonte       VARCHAR(10)  NOT NULL,
    descricao       VARCHAR(40)  NOT NULL,
    renovavel       BOOLEAN      NOT NULL,
    intermitente    BOOLEAN      NOT NULL,   -- depende de sol/vento
    PRIMARY KEY (id_fonte),
    UNIQUE KEY uk_fonte_cod (cod_fonte)
);

INSERT INTO fonte_energia (cod_fonte, descricao, renovavel, intermitente) VALUES
  ('UHE', 'Hidrelétrica',              TRUE,  FALSE),
  ('PCH', 'Pequena Central Hidrelétrica', TRUE,  FALSE),
  ('UFV', 'Solar fotovoltaica',        TRUE,  TRUE),
  ('EOL', 'Eólica',                    TRUE,  TRUE),
  ('BIO', 'Biomassa (bagaço de cana)', TRUE,  FALSE),
  ('UTE', 'Térmica a gás natural',     FALSE, FALSE);


-- 1.3 Usinas da Campo Real Energia (empresa fictícia)
CREATE TABLE usina (
    id_usina             INT           NOT NULL AUTO_INCREMENT,
    cod_usina            VARCHAR(12)   NOT NULL,      -- chave de negócio
    nome                 VARCHAR(80)   NOT NULL,
    id_fonte             TINYINT       NOT NULL,
    cod_submercado       CHAR(2)       NOT NULL,
    uf                   CHAR(2)       NOT NULL,
    municipio            VARCHAR(60)   NOT NULL,
    latitude             DECIMAL(9,6)  NOT NULL,
    longitude            DECIMAL(9,6)  NOT NULL,
    potencia_mw          DECIMAL(8,2)  NOT NULL,      -- potência instalada
    data_inicio_operacao DATE          NOT NULL,
    situacao             VARCHAR(20)   NOT NULL DEFAULT 'Em operação',
    PRIMARY KEY (id_usina),
    UNIQUE KEY uk_usina_cod (cod_usina),
    CONSTRAINT fk_usina_fonte      FOREIGN KEY (id_fonte)       REFERENCES fonte_energia (id_fonte),
    CONSTRAINT fk_usina_submercado FOREIGN KEY (cod_submercado) REFERENCES submercado (cod_submercado)
);

INSERT INTO usina (cod_usina, nome, id_fonte, cod_submercado, uf, municipio,
                   latitude, longitude, potencia_mw, data_inicio_operacao)
SELECT u.cod_usina, u.nome, f.id_fonte, u.sub, u.uf, u.municipio,
       u.lat, u.lon, u.mw, u.inicio
FROM (
  SELECT 'CRE-UHE-001' AS cod_usina, 'UHE Campo Real Iguaçu'    AS nome, 'UHE' AS fonte, 'S'  AS sub, 'PR' AS uf, 'Capitão Leônidas Marques' AS municipio, -25.4800 AS lat, -53.6100 AS lon, 180.00 AS mw, DATE '2009-03-01' AS inicio
  UNION ALL SELECT 'CRE-PCH-002', 'PCH Rio das Araucárias',  'PCH', 'S',  'SC', 'Caçador',          -26.7750, -51.0150,  25.00, DATE '2014-08-15'
  UNION ALL SELECT 'CRE-EOL-003', 'EOL Coxilha Real',        'EOL', 'S',  'RS', 'Santana do Livramento', -30.8900, -55.5300,  50.00, DATE '2016-11-01'
  UNION ALL SELECT 'CRE-UFV-004', 'UFV Campo Real Minas',    'UFV', 'SE', 'MG', 'Janaúba',          -15.8030, -43.3080,  60.00, DATE '2020-06-01'
  UNION ALL SELECT 'CRE-BIO-005', 'UTE Bagaço Campo Real',   'BIO', 'SE', 'SP', 'Sertãozinho',      -21.1380, -47.9900,  40.00, DATE '2012-04-01'
  UNION ALL SELECT 'CRE-UFV-006', 'UFV Sertão do Sol',       'UFV', 'NE', 'BA', 'Bom Jesus da Lapa', -13.2550, -43.4180,  90.00, DATE '2019-02-01'
  UNION ALL SELECT 'CRE-EOL-007', 'EOL Ventos do Potiguar',  'EOL', 'NE', 'RN', 'João Câmara',       -5.5370, -35.8190, 120.00, DATE '2015-09-01'
  UNION ALL SELECT 'CRE-UHE-008', 'UHE Tocantins Real',      'UHE', 'N',  'TO', 'Peixe',            -12.0250, -48.5400, 110.00, DATE '2006-05-01'
  UNION ALL SELECT 'CRE-UTE-009', 'UTE Gás Norte',           'UTE', 'N',  'MA', 'Santo Antônio dos Lopes', -4.8670, -44.3600, 150.00, DATE '2013-01-01'
) AS u
JOIN fonte_energia f ON f.cod_fonte = u.fonte;


-- 1.4 Feriados nacionais de 2025 (insumo para a futura dimensão de tempo)
CREATE TABLE feriado_nacional (
    data        DATE         NOT NULL,
    descricao   VARCHAR(60)  NOT NULL,
    tipo        VARCHAR(20)  NOT NULL,   -- 'Feriado' ou 'Ponto facultativo'
    PRIMARY KEY (data)
);

INSERT INTO feriado_nacional (data, descricao, tipo) VALUES
  ('2025-01-01', 'Confraternização Universal',  'Feriado'),
  ('2025-03-03', 'Carnaval',                    'Ponto facultativo'),
  ('2025-03-04', 'Carnaval',                    'Ponto facultativo'),
  ('2025-04-18', 'Sexta-feira Santa',           'Feriado'),
  ('2025-04-21', 'Tiradentes',                  'Feriado'),
  ('2025-05-01', 'Dia do Trabalho',             'Feriado'),
  ('2025-06-19', 'Corpus Christi',              'Ponto facultativo'),
  ('2025-09-07', 'Independência do Brasil',     'Feriado'),
  ('2025-10-12', 'Nossa Senhora Aparecida',     'Feriado'),
  ('2025-11-02', 'Finados',                     'Feriado'),
  ('2025-11-15', 'Proclamação da República',    'Feriado'),
  ('2025-11-20', 'Dia da Consciência Negra',    'Feriado'),
  ('2025-12-25', 'Natal',                       'Feriado');


/* =====================================================================
   PASSO 2 - Tabelas de operação
   ===================================================================== */

-- 2.1 Paradas das usinas (manutenção programada e falhas)
CREATE TABLE parada_usina (
    id_parada    INT          NOT NULL AUTO_INCREMENT,
    id_usina     INT          NOT NULL,
    inicio       DATETIME     NOT NULL,
    fim          DATETIME     NOT NULL,
    tipo         VARCHAR(20)  NOT NULL,   -- 'Programada' ou 'Forçada'
    motivo       VARCHAR(120) NOT NULL,
    PRIMARY KEY (id_parada),
    CONSTRAINT fk_parada_usina FOREIGN KEY (id_usina) REFERENCES usina (id_usina)
);

INSERT INTO parada_usina (id_usina, inicio, fim, tipo, motivo)
SELECT u.id_usina, p.inicio, p.fim, p.tipo, p.motivo
FROM (
  SELECT 'CRE-UHE-001' AS cod, TIMESTAMP '2025-07-07 00:00:00' AS inicio, TIMESTAMP '2025-07-13 23:00:00' AS fim, 'Programada' AS tipo, 'Revisão geral da unidade geradora 1' AS motivo
  UNION ALL SELECT 'CRE-PCH-002', '2025-03-10 08:00:00', '2025-03-11 17:00:00', 'Forçada',    'Falha no regulador de velocidade'
  UNION ALL SELECT 'CRE-EOL-003', '2025-05-20 00:00:00', '2025-05-22 23:00:00', 'Programada', 'Troca de caixa multiplicadora'
  UNION ALL SELECT 'CRE-UFV-004', '2025-02-14 13:00:00', '2025-02-14 18:00:00', 'Forçada',    'Desarme do inversor central após descarga atmosférica'
  UNION ALL SELECT 'CRE-BIO-005', '2025-12-01 00:00:00', '2025-12-31 23:00:00', 'Programada', 'Entressafra: manutenção da caldeira'
  UNION ALL SELECT 'CRE-UFV-006', '2025-10-02 09:00:00', '2025-10-03 16:00:00', 'Forçada',    'Falha no transformador elevador'
  UNION ALL SELECT 'CRE-EOL-007', '2025-04-14 00:00:00', '2025-04-17 23:00:00', 'Programada', 'Inspeção de pás'
  UNION ALL SELECT 'CRE-EOL-007', '2025-09-08 05:00:00', '2025-09-08 20:00:00', 'Forçada',    'Restrição de transmissão (constrained-off)'
  UNION ALL SELECT 'CRE-UHE-008', '2025-08-18 00:00:00', '2025-08-24 23:00:00', 'Programada', 'Manutenção da comporta do vertedouro'
  UNION ALL SELECT 'CRE-UTE-009', '2025-06-02 00:00:00', '2025-06-15 23:00:00', 'Programada', 'Overhaul da turbina a gás'
) AS p
JOIN usina u ON u.cod_usina = p.cod;


-- 2.2 Medição horária de geração (grão esperado: 1 usina x 1 hora)
--     Esta tabela imita a exportação do sistema de medição (SCADA), que
--     NÃO tem chave única, nem chave estrangeira, nem NOT NULL na energia.
--     Ou seja: o banco não protege nada. Garantir a qualidade é com vocês.
CREATE TABLE medicao_geracao (
    id_medicao        BIGINT        NOT NULL AUTO_INCREMENT,
    id_usina          INT,
    data_hora         DATETIME,                 -- início da hora, horário de Brasília
    energia_mwh       DECIMAL(12,3),            -- energia gerada na hora
    disponibilidade_mw DECIMAL(8,2),            -- potência disponível na hora
    origem            VARCHAR(20)   DEFAULT 'SCADA',
    recebido_em       DATETIME,                 -- quando o dado chegou ao banco
    PRIMARY KEY (id_medicao),
    KEY idx_medicao_usina_data (id_usina, data_hora),
    KEY idx_medicao_data (data_hora)
);


/* =====================================================================
   PASSO 3 - Gerar a geração horária FAKE de 2025
   ---------------------------------------------------------------------
   Lógica (simplificada, mas com comportamento realista):
     - Solar  : só gera entre 6h e 18h, curva em sino, com nuvens aleatórias
     - Eólica : mais vento no 2º semestre e à noite (forte no Nordeste)
     - Hídrica: mais água no período úmido (dez-abr), pico no fim da tarde
     - Biomassa: só na safra da cana (abr-nov)
     - Gás     : despacha no horário de ponta e na seca (ago-nov)
   O "ruído" usa CRC32, então o resultado é sempre o mesmo em qualquer
   computador (reprodutível).
   ===================================================================== */

-- 3.1 Tabela auxiliar com as 8.760 horas do ano
SET SESSION cte_max_recursion_depth = 10000;

CREATE TEMPORARY TABLE tmp_horas (data_hora DATETIME PRIMARY KEY);

INSERT INTO tmp_horas (data_hora)
WITH RECURSIVE horas AS (
    SELECT TIMESTAMP '2025-01-01 00:00:00' AS data_hora
    UNION ALL
    SELECT data_hora + INTERVAL 1 HOUR
    FROM horas
    WHERE data_hora < TIMESTAMP '2025-12-31 23:00:00'
)
SELECT data_hora FROM horas;

SELECT COUNT(*) AS total_horas FROM tmp_horas;   -- esperado: 8760


-- 3.2 Calcular o fator de capacidade de cada usina em cada hora
INSERT INTO medicao_geracao (id_usina, data_hora, energia_mwh, disponibilidade_mw, recebido_em)
SELECT
    b.id_usina,
    b.data_hora,
    ROUND(b.potencia_mw * GREATEST(0, LEAST(0.98,
        CASE b.cod_fonte
          WHEN 'UFV' THEN
               GREATEST(0, SIN(PI() * (b.h - 6) / 12))                 -- curva do sol
             * (1 + 0.08 * COS(2 * PI() * (b.doy - 15) / 365))         -- mais forte no verão
             * (0.55 + 0.45 * b.ruido)                                 -- nuvens
             * 0.88
          WHEN 'EOL' THEN
               (CASE b.cod_submercado WHEN 'NE' THEN 0.30 ELSE 0.22 END)
             + (CASE b.cod_submercado WHEN 'NE' THEN 0.35 ELSE 0.18 END)
               * (1 + COS(2 * PI() * (b.doy - 242) / 365)) / 2         -- safra de ventos (ago-set)
             + 0.12 * COS(2 * PI() * (b.h - 2) / 24)                   -- venta mais de madrugada
             + 0.35 * (b.ruido - 0.5)
          WHEN 'UHE' THEN
               (CASE b.cod_submercado WHEN 'S' THEN 0.58 ELSE 0.52 END)
             + (CASE b.cod_submercado WHEN 'S' THEN 0.08 ELSE 0.25 END)
               * COS(2 * PI() * (b.doy - 45) / 365)                    -- período úmido
             + 0.10 * SIN(PI() * (b.h - 6) / 18) * (b.h BETWEEN 6 AND 23)  -- acompanha a carga
             + 0.08 * (b.ruido - 0.5)
          WHEN 'PCH' THEN
               0.60 + 0.15 * COS(2 * PI() * (b.doy - 30) / 365)
             + 0.10 * (b.ruido - 0.5)
          WHEN 'BIO' THEN
               CASE WHEN b.mes BETWEEN 4 AND 11
                    THEN 0.78 + 0.15 * (b.ruido - 0.5)
                    ELSE 0.02 + 0.03 * b.ruido END
          WHEN 'UTE' THEN
               CASE WHEN b.h BETWEEN 17 AND 21 AND b.ruido > 0.25 THEN 0.84 + 0.08 * b.ruido
                    WHEN b.mes BETWEEN 8 AND 11 AND b.ruido > 0.40 THEN 0.76 + 0.08 * b.ruido
                    WHEN b.ruido > 0.93                         THEN 0.60 + 0.05 * b.ruido
                    ELSE 0 END
        END
    )), 3) AS energia_mwh,
    b.potencia_mw AS disponibilidade_mw,
    b.data_hora + INTERVAL (65 + FLOOR(b.ruido * 40)) MINUTE AS recebido_em   -- chega ~1h depois
FROM (
    SELECT u.id_usina, u.potencia_mw, u.cod_submercado, f.cod_fonte,
           t.data_hora,
           HOUR(t.data_hora)      AS h,
           MONTH(t.data_hora)     AS mes,
           DAYOFYEAR(t.data_hora) AS doy,
           (CRC32(CONCAT(u.cod_usina, '|', t.data_hora)) % 10000) / 10000 AS ruido
    FROM usina u
    JOIN fonte_energia f ON f.id_fonte = u.id_fonte
    CROSS JOIN tmp_horas t
) AS b;

DROP TEMPORARY TABLE tmp_horas;


-- 3.3 Zerar a geração e a disponibilidade nas horas de parada
UPDATE medicao_geracao m
JOIN parada_usina p
  ON p.id_usina = m.id_usina
 AND m.data_hora BETWEEN p.inicio AND p.fim
SET m.energia_mwh        = 0,
    m.disponibilidade_mw = 0;


-- 3.4 Conferência
SELECT u.cod_usina, u.nome,
       COUNT(*)                                   AS horas,          -- esperado: 8760
       ROUND(SUM(m.energia_mwh) / 1000, 1)        AS gwh_ano,
       ROUND(SUM(m.energia_mwh) / (u.potencia_mw * 8760) * 100, 1) AS fator_capacidade_pct
FROM medicao_geracao m
JOIN usina u ON u.id_usina = m.id_usina
GROUP BY u.id_usina, u.cod_usina, u.nome, u.potencia_mw
ORDER BY u.id_usina;


/* =====================================================================
   PASSO 4 - Extração do PLD horário REAL (CCEE)
   ---------------------------------------------------------------------
   4.1 Baixe o CSV de 2025 em:
       https://dadosabertos.ccee.org.br/dataset/pld_horario
       -> recurso "pld_horario_2025" -> Baixar -> CSV
       Link direto do CSV do portal (CKAN):
       https://dadosabertos.ccee.org.br/datastore/dump/2a180a6b-f092-43eb-9f82-a48798b803dc

   Colunas segundo o dicionário de dados da CCEE:
       MES_REFERENCIA (AAAAMM), SUBMERCADO, PERIODO_COMERCIALIZACAO,
       DIA (DD/MM/AAAA), HORA, PLD_HORA (R$/MWh)
   O CSV do link direto vem com uma coluna extra "_id" no começo.

   ABRA O ARQUIVO NUM EDITOR DE TEXTO ANTES DE CARREGAR e confira:
     - o separador (vírgula ou ponto e vírgula)
     - se existe a coluna _id
     - o formato da data e do número
   Isso é parte do trabalho de engenharia de dados.
   ===================================================================== */

-- 4.2 Staging: guarda o CSV exatamente como veio (tudo texto)
CREATE TABLE stg_pld_horario (
    id_ckan                 VARCHAR(20),
    mes_referencia          VARCHAR(10),
    submercado              VARCHAR(40),
    periodo_comercializacao VARCHAR(10),
    dia                     VARCHAR(30),
    hora                    VARCHAR(10),
    pld_hora                VARCHAR(30),
    arquivo_origem          VARCHAR(100),
    carregado_em            DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 4.3 Tabela tratada do PLD (grão: 1 submercado x 1 hora)
CREATE TABLE pld_horario (
    cod_submercado          CHAR(2)        NOT NULL,
    data_hora               DATETIME       NOT NULL,   -- início da hora, horário de Brasília
    mes_referencia          CHAR(6)        NOT NULL,
    periodo_comercializacao SMALLINT       NOT NULL,
    pld_rs_mwh              DECIMAL(10,2)  NOT NULL,
    origem                  VARCHAR(20)    NOT NULL,   -- 'CCEE' ou 'SIMULADO'
    PRIMARY KEY (cod_submercado, data_hora),
    CONSTRAINT fk_pld_submercado FOREIGN KEY (cod_submercado) REFERENCES submercado (cod_submercado)
);

-- 4.4 Log de cargas
CREATE TABLE log_carga (
    id_log        INT          NOT NULL AUTO_INCREMENT,
    tabela        VARCHAR(40)  NOT NULL,
    arquivo       VARCHAR(100),
    linhas        INT,
    status        VARCHAR(20)  NOT NULL,
    observacao    VARCHAR(255),
    registrado_em DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_log)
);


/* ---------------------------------------------------------------------
   4.5 Carregar o CSV na staging

   Pré-requisito: LOAD DATA LOCAL precisa estar liberado.
     - No servidor:  SET GLOBAL local_infile = 1;   (usuário com privilégio)
     - No MySQL Workbench: editar a conexão > Advanced > Others:
           OPT_LOCAL_INFILE=1
     - No terminal:  mysql --local-infile=1 -u root -p
   Alternativa sem LOAD DATA: botão direito em stg_pld_horario >
   "Table Data Import Wizard" no Workbench.

   Troque o caminho abaixo pelo local onde salvou o arquivo.
   No Windows use barras normais: 'C:/Users/aluno/Downloads/pld_horario_2025.csv'
   --------------------------------------------------------------------- */
SET GLOBAL local_infile = 1;

TRUNCATE TABLE stg_pld_horario;

-- Opção A: CSV do link direto do portal (vírgula, com coluna _id)
LOAD DATA LOCAL INFILE 'C:/Users/aluno/Downloads/pld_horario_2025.csv'
INTO TABLE stg_pld_horario
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_ckan, mes_referencia, submercado, periodo_comercializacao, dia, hora, pld_hora)
SET arquivo_origem = 'pld_horario_2025.csv';

-- Opção B: arquivo SEM a coluna _id e separado por ponto e vírgula
-- (use esta no lugar da opção A se o cabeçalho começar em MES_REFERENCIA)
-- LOAD DATA LOCAL INFILE 'C:/Users/aluno/Downloads/pld_horario_2025.csv'
-- INTO TABLE stg_pld_horario
-- CHARACTER SET utf8mb4
-- FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 LINES
-- (mes_referencia, submercado, periodo_comercializacao, dia, hora, pld_hora)
-- SET arquivo_origem = 'pld_horario_2025.csv';


-- 4.6 Inspecionar a staging ANTES de transformar
SELECT COUNT(*) AS linhas FROM stg_pld_horario;            -- esperado: ~35.040 (8760 x 4)
SELECT * FROM stg_pld_horario LIMIT 10;
SELECT submercado, COUNT(*) FROM stg_pld_horario GROUP BY submercado;
SELECT MIN(CAST(hora AS UNSIGNED)) AS hora_min,
       MAX(CAST(hora AS UNSIGNED)) AS hora_max                -- 0-23 ou 1-24?
FROM stg_pld_horario;


-- 4.7 Transformar staging -> pld_horario
--     Trata: nome do submercado, formato da data, vírgula decimal,
--     \r no fim da linha (arquivo Windows) e hora 1-24 vs 0-23.
SET @desloc_hora := (SELECT IF(MAX(CAST(hora AS UNSIGNED)) = 24, 1, 0) FROM stg_pld_horario);

INSERT INTO pld_horario (cod_submercado, data_hora, mes_referencia,
                         periodo_comercializacao, pld_rs_mwh, origem)
SELECT
    CASE
      WHEN UPPER(TRIM(s.submercado)) IN ('SE', 'SUDESTE', 'SUDESTE/CENTRO-OESTE', 'SE/CO') THEN 'SE'
      WHEN UPPER(TRIM(s.submercado)) IN ('S', 'SUL')                                      THEN 'S'
      WHEN UPPER(TRIM(s.submercado)) IN ('NE', 'NORDESTE')                                THEN 'NE'
      WHEN UPPER(TRIM(s.submercado)) IN ('N', 'NORTE')                                    THEN 'N'
    END AS cod_submercado,
    TIMESTAMP(
      CASE WHEN TRIM(s.dia) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}'
           THEN STR_TO_DATE(LEFT(TRIM(s.dia), 10), '%d/%m/%Y')
           ELSE STR_TO_DATE(LEFT(TRIM(s.dia), 10), '%Y-%m-%d')
      END
    ) + INTERVAL (CAST(s.hora AS UNSIGNED) - @desloc_hora) HOUR AS data_hora,
    LEFT(TRIM(s.mes_referencia), 6),
    CAST(s.periodo_comercializacao AS UNSIGNED),
    CAST(
      CASE WHEN REPLACE(s.pld_hora, '\r', '') LIKE '%,%'
           THEN REPLACE(REPLACE(TRIM(REPLACE(s.pld_hora, '\r', '')), '.', ''), ',', '.')
           ELSE TRIM(REPLACE(s.pld_hora, '\r', ''))
      END AS DECIMAL(10,2)
    ),
    'CCEE'
FROM stg_pld_horario s
WHERE TRIM(s.pld_hora) <> ''
ON DUPLICATE KEY UPDATE                     -- rodar de novo não duplica
    pld_rs_mwh = VALUES(pld_rs_mwh),
    origem     = VALUES(origem);

INSERT INTO log_carga (tabela, arquivo, linhas, status, observacao)
SELECT 'pld_horario', 'pld_horario_2025.csv', COUNT(*), 'OK', 'Carga do PLD horário CCEE 2025'
FROM pld_horario WHERE origem = 'CCEE';


-- 4.8 Conferência do PLD
SELECT cod_submercado,
       COUNT(*)              AS horas,       -- esperado: 8760 por submercado
       MIN(pld_rs_mwh)       AS pld_min,
       ROUND(AVG(pld_rs_mwh), 2) AS pld_medio,
       MAX(pld_rs_mwh)       AS pld_max
FROM pld_horario
GROUP BY cod_submercado;


/* ---------------------------------------------------------------------
   4.9 PLANO B (só se não conseguir baixar ou carregar o CSV)
   Gera um PLD SIMULADO com origem = 'SIMULADO' para a aula não travar.
   Descomente o bloco abaixo e rode. Depois, quando conseguir o arquivo,
   rode o passo 4.7: os valores reais substituem os simulados.
   --------------------------------------------------------------------- */
-- SET SESSION cte_max_recursion_depth = 10000;
-- INSERT IGNORE INTO pld_horario (cod_submercado, data_hora, mes_referencia,
--                                 periodo_comercializacao, pld_rs_mwh, origem)
-- WITH RECURSIVE horas AS (
--     SELECT TIMESTAMP '2025-01-01 00:00:00' AS data_hora
--     UNION ALL
--     SELECT data_hora + INTERVAL 1 HOUR FROM horas
--     WHERE data_hora < TIMESTAMP '2025-12-31 23:00:00'
-- )
-- SELECT s.cod_submercado,
--        h.data_hora,
--        DATE_FORMAT(h.data_hora, '%Y%m'),
--        (DAY(h.data_hora) - 1) * 24 + HOUR(h.data_hora) + 1,
--        ROUND(LEAST(1500, GREATEST(58.60,
--              120
--            + 150 * (1 - COS(2 * PI() * (DAYOFYEAR(h.data_hora) - 60) / 365)) / 2  -- seca encarece
--            - 60 * (HOUR(h.data_hora) BETWEEN 10 AND 15)                        -- sol derruba o preço
--            + 90 * (HOUR(h.data_hora) BETWEEN 18 AND 21)                        -- ponta encarece
--            + 80 * ((CRC32(CONCAT(s.cod_submercado, h.data_hora)) % 1000) / 1000 - 0.5)
--        )), 2),
--        'SIMULADO'
-- FROM horas h
-- CROSS JOIN submercado s;


/* =====================================================================
   PASSO 5 - Simular a vida real: falhas de sistema, digitação e integração
   ---------------------------------------------------------------------
   Nenhum dado real é limpo. Este passo reproduz o que acontece numa
   comercializadora de verdade: medidor que trava, reprocessamento que
   duplica, operador que digita errado, cadastro feito às pressas,
   integração que atrasa.

   IMPORTANTE: rode este passo DEPOIS de carregar o PLD (passo 4.7 ou 4.9).

   Missão dos alunos: encontrar os problemas, classificá-los nas
   dimensões de qualidade (completude, unicidade, validade, consistência,
   acurácia, atualidade/tempestividade, integridade referencial),
   medir quantos registros cada um afeta e propor o tratamento.
   ===================================================================== */

SET @uhe1 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-UHE-001');
SET @pch2 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-PCH-002');
SET @eol3 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-EOL-003');
SET @ufv4 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-UFV-004');
SET @bio5 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-BIO-005');
SET @ufv6 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-UFV-006');
SET @eol7 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-EOL-007');
SET @uhe8 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-UHE-008');
SET @ute9 := (SELECT id_usina FROM usina WHERE cod_usina = 'CRE-UTE-009');

-- 5.1 Cadastro de usinas feito às pressas
INSERT INTO usina (cod_usina, nome, id_fonte, cod_submercado, uf, municipio,
                   latitude, longitude, potencia_mw, data_inicio_operacao)
SELECT 'CRE-EOL-07', 'Eol Ventos do Potiguar ', id_fonte, cod_submercado, uf, '',
       latitude, longitude, potencia_mw, data_inicio_operacao
FROM usina WHERE cod_usina = 'CRE-EOL-007';

UPDATE usina SET latitude = 15.803000              WHERE cod_usina = 'CRE-UFV-004';
UPDATE usina SET data_inicio_operacao = '2031-02-01' WHERE cod_usina = 'CRE-UFV-006';
UPDATE usina SET uf = 'PE'                          WHERE cod_usina = 'CRE-BIO-005';

-- 5.2 Registro de parada lançado manualmente
INSERT INTO parada_usina (id_usina, inicio, fim, tipo, motivo)
VALUES (@ufv4, '2025-11-05 18:00:00', '2025-11-05 08:00:00', 'Forçada', 'Limpeza emergencial dos módulos');

-- 5.3 Falhas no sistema de medição
-- falha de comunicação
UPDATE medicao_geracao SET energia_mwh = NULL
 WHERE id_usina = @uhe8 AND data_hora BETWEEN '2025-03-05 10:00:00' AND '2025-03-05 15:00:00';

-- dia que não chegou
DELETE FROM medicao_geracao
 WHERE id_usina = @eol3 AND DATE(data_hora) = '2025-11-10';

-- dados que pararam de chegar no fim do ano
DELETE FROM medicao_geracao
 WHERE id_usina = @ufv4 AND data_hora >= '2025-12-29 00:00:00';

-- reprocessamento da integração
INSERT INTO medicao_geracao (id_usina, data_hora, energia_mwh, disponibilidade_mw, origem, recebido_em)
SELECT id_usina, data_hora, energia_mwh, disponibilidade_mw, origem, recebido_em + INTERVAL 1 DAY
FROM medicao_geracao
WHERE id_usina = @ufv4 AND DATE(data_hora) = '2025-01-20';

-- lançamento manual por cima da leitura automática
INSERT INTO medicao_geracao (id_usina, data_hora, energia_mwh, disponibilidade_mw, origem, recebido_em)
SELECT id_usina, data_hora, ROUND(energia_mwh * 1.10, 3), disponibilidade_mw, 'MANUAL', recebido_em + INTERVAL 2 DAY
FROM medicao_geracao
WHERE id_usina = @pch2 AND data_hora BETWEEN '2025-06-01 08:00:00' AND '2025-06-01 11:00:00';

-- consumo dos serviços auxiliares registrado como geração
UPDATE medicao_geracao SET energia_mwh = -0.850
 WHERE id_usina = @eol7 AND data_hora BETWEEN '2025-02-03 01:00:00' AND '2025-02-03 04:00:00';

-- erro de digitação no ano e registro sem usina
INSERT INTO medicao_geracao (id_usina, data_hora, energia_mwh, disponibilidade_mw, origem, recebido_em) VALUES
  (@ufv6, '2052-05-14 10:00:00', 55.200, 90.00, 'MANUAL', '2025-05-14 11:10:00'),
  (NULL,  '2025-10-20 14:00:00', 33.100, NULL,  'MANUAL', '2025-10-20 15:20:00');

-- medições de um equipamento que não está no cadastro
INSERT INTO medicao_geracao (id_usina, data_hora, energia_mwh, disponibilidade_mw, origem, recebido_em)
SELECT 99, data_hora, energia_mwh, disponibilidade_mw, origem, recebido_em
FROM medicao_geracao
WHERE id_usina = @eol7 AND DATE(data_hora) = '2025-10-15';

-- vírgula deslocada e pico de leitura
UPDATE medicao_geracao SET energia_mwh = energia_mwh * 10
 WHERE id_usina = @uhe1 AND data_hora = '2025-04-22 14:00:00';
UPDATE medicao_geracao SET energia_mwh = 499.000
 WHERE id_usina = @eol3 AND data_hora = '2025-07-03 03:00:00';

-- medidor travado
UPDATE medicao_geracao SET energia_mwh = 31.250
 WHERE id_usina = @bio5 AND data_hora BETWEEN '2025-09-01 00:00:00' AND '2025-09-03 23:00:00';

-- leitura com relógio do medidor errado
UPDATE medicao_geracao SET energia_mwh = 15.400
 WHERE id_usina = @ufv6 AND data_hora BETWEEN '2025-08-12 20:00:00' AND '2025-08-12 23:00:00';

-- geração lançada durante manutenção
UPDATE medicao_geracao SET energia_mwh = 132.000
 WHERE id_usina = @ute9 AND data_hora BETWEEN '2025-06-05 18:00:00' AND '2025-06-05 21:00:00';

-- planilha digitada em kWh
UPDATE medicao_geracao SET energia_mwh = energia_mwh * 1000, origem = 'MANUAL'
 WHERE id_usina = @bio5 AND DATE(data_hora) = '2025-05-10';

-- integração atrasada
UPDATE medicao_geracao SET recebido_em = '2026-02-10 09:00:00' + INTERVAL HOUR(data_hora) MINUTE
 WHERE id_usina = @uhe8 AND data_hora >= '2025-12-20 00:00:00';

-- relógio do servidor errado
UPDATE medicao_geracao SET recebido_em = data_hora - INTERVAL 3 DAY
 WHERE id_usina = @pch2 AND DATE(data_hora) = '2025-08-05';

-- 5.4 Problemas na base de preços
DELETE FROM pld_horario
 WHERE cod_submercado = 'NE' AND DATE(data_hora) = '2025-05-18';
UPDATE pld_horario SET pld_rs_mwh = 15422.30
 WHERE cod_submercado = 'SE' AND data_hora = '2025-02-10 19:00:00';
UPDATE pld_horario SET pld_rs_mwh = -58.60
 WHERE cod_submercado = 'S'  AND data_hora = '2025-03-12 03:00:00';


/* =====================================================================
   PASSO 6 - Verificação final do banco
   ===================================================================== */
SELECT 'submercado'       AS tabela, COUNT(*) AS linhas FROM submercado
UNION ALL SELECT 'fonte_energia',    COUNT(*) FROM fonte_energia
UNION ALL SELECT 'usina',            COUNT(*) FROM usina               -- 10
UNION ALL SELECT 'feriado_nacional', COUNT(*) FROM feriado_nacional
UNION ALL SELECT 'parada_usina',     COUNT(*) FROM parada_usina
UNION ALL SELECT 'medicao_geracao',  COUNT(*) FROM medicao_geracao     -- 78.798
UNION ALL SELECT 'stg_pld_horario',  COUNT(*) FROM stg_pld_horario
UNION ALL SELECT 'pld_horario',      COUNT(*) FROM pld_horario         -- 35.016
UNION ALL SELECT 'log_carga',        COUNT(*) FROM log_carga;

-- Teste rápido: as duas tabelas "conversam" pela hora e pelo submercado?
SELECT u.nome, m.data_hora, m.energia_mwh, p.pld_rs_mwh
FROM medicao_geracao m
JOIN usina u       ON u.id_usina = m.id_usina
JOIN pld_horario p ON p.cod_submercado = u.cod_submercado
                  AND p.data_hora      = m.data_hora
WHERE m.data_hora = '2025-09-15 12:00:00';


/* =====================================================================
   PARA OS ALUNOS (desafio)
   A partir destas tabelas, projetem e construam o star schema:
     - Qual é o grão de medicao_geracao? E de pld_horario? São iguais?
     - Que informação de tempo vocês precisam (hora, dia útil, feriado,
       mês, estação do ano, patamar de carga)? De onde ela vem?
     - usina, fonte_energia e submercado viram dimensões separadas ou
       uma só? Justifiquem.
     - Chave natural (cod_usina) x chave substituta: qual vai no fato?
     - Como tratar as horas de parada_usina no modelo?
     - Pergunta de negócio: quanto a Campo Real teria faturado se
       vendesse toda a geração ao PLD? Qual fonte "captura" o melhor preço?
     - Antes de carregar o star schema: rodem um profiling das tabelas,
       listem os problemas por dimensão de qualidade, gravem as métricas
       numa tabela e decidam o que corrigir, descartar ou só sinalizar.
       Quanto o faturamento muda antes e depois da limpeza?
   ===================================================================== */
