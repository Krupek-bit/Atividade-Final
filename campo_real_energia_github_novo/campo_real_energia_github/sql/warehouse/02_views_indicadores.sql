USE dw_campo_real;

CREATE OR REPLACE VIEW vw_receita_geracao AS
SELECT t.data_hora, u.nome_usina, u.fonte_energia, u.submercado,
       SUM(g.geracao_mwh) AS geracao_mwh,
       MAX(p.pld_mwh) AS pld_mwh,
       SUM(g.geracao_mwh * p.pld_mwh) AS receita_valorada
FROM fato_geracao g
JOIN dim_tempo t ON t.tempo_sk=g.tempo_sk
JOIN dim_usina u ON u.usina_sk=g.usina_sk
JOIN fato_pld p ON p.tempo_sk=g.tempo_sk AND p.submercado_sk=g.submercado_sk
GROUP BY t.data_hora,u.nome_usina,u.fonte_energia,u.submercado;

CREATE OR REPLACE VIEW vw_indicadores_mensais AS
SELECT YEAR(data_hora) ano, MONTH(data_hora) mes, nome_usina,
       fonte_energia, submercado, SUM(geracao_mwh) geracao_mwh,
       SUM(receita_valorada) receita_valorada,
       SUM(receita_valorada)/NULLIF(SUM(geracao_mwh),0) preco_capturado
FROM vw_receita_geracao
GROUP BY YEAR(data_hora),MONTH(data_hora),nome_usina,fonte_energia,submercado;
