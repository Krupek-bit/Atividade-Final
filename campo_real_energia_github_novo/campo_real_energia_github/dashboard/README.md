# Dashboard — Power BI / Tableau
Conectar somente ao schema `dw_campo_real`.

## Páginas recomendadas
1. Visão executiva: geração total, receita valorada, PLD médio e preço capturado.
2. Geração: evolução mensal por usina, fonte e submercado; fator de capacidade.
3. Preços: mapa de calor mês × hora, preço capturado e razão de captura por fonte.
4. Paradas: horas indisponíveis e estimativa de energia/receita não gerada.
5. Qualidade: indicadores antes/depois e registros sinalizados.

## Medidas
- Receita valorada = soma de geração horária × PLD horário do submercado.
- Preço capturado = receita valorada ÷ geração.
- Razão de captura = preço capturado ÷ PLD médio do submercado.
- Fator de capacidade = geração ÷ (potência instalada × horas do período).

Salvar o `.pbix` ou arquivo Tableau nesta pasta e documentar medidas, filtros e decisões.
