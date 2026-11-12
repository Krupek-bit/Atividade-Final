# Campo Real Energia — Data Warehouse

Projeto acadêmico de DW: extração de dados abertos, qualidade em Python, modelagem dimensional e indicadores em Power BI/Tableau.

## Fluxo
**Banco operacional → APIs públicas → camada raw → qualidade → star schema → dashboard**

## Estrutura
```text
campo_real_energia/
├── dashboard/                 # documentação e arquivo final do painel
├── data/raw/                  # respostas originais das APIs (não versionar dados grandes)
├── data/processed/            # relatórios de profiling
├── docs/                      # enunciado e decisões de modelagem
├── python/campo_real/         # configuração, conexão e regras reutilizáveis
├── python/scripts/            # extração CCEE, clima e qualidade
└── sql/
    ├── origem/                # SQL MySQL 8 fornecido
    └── warehouse/             # DDL e views do DW
```

## Preparação
Requisitos: Python 3.10+ e MySQL 8.

```bash
python -m venv .venv
# Windows: .venv\Scripts\Activate.ps1
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
```

Copie `.env.example` para `.env` e preencha a conexão e os `resource_id` de PLD 2025 e 2026 obtidos na página oficial do conjunto PLD_HORARIO da CCEE.

## Banco de origem
Execute `sql/origem/campo_real_energia.sql` no MySQL 8. **Atenção:** o script contém `DROP DATABASE IF EXISTS campo_real_energia`; faça backup e confirme antes de executá-lo.

## Extração
```bash
python -m python.scripts.extrair_pld
python -m python.scripts.extrair_clima
```
O PLD usa a API CKAN da CCEE, pagina até não haver mais registros, salva o JSON original em `data/raw/ccee/` e grava cada registro em `raw_pld_ccee`. O clima usa Open-Meteo nas coordenadas das usinas e grava as respostas originais e os dados horários.

## Qualidade
```bash
python -m python.scripts.qualidade
```
Gera profiling CSV e persiste métricas iniciais de completude, unicidade, validade, integridade referencial e atualidade. Os registros são sinalizados, não corrigidos automaticamente: cada tratamento deve ser justificado pelo grupo.

## Data Warehouse
Execute `sql/warehouse/01_ddl_dw.sql` e depois `02_views_indicadores.sql`. Os grãos e a estratégia SCD estão documentados em `docs/decisoes_modelagem.md`.

## Dashboard


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

O relatório Power BI/Tableau deve consumir **somente** o schema `dw_campo_real`. Veja `dashboard/README.md`.

## Atenção
O `resource_id` da CCEE deve ser conferido no portal oficial; não foi inventado no código. A estrutura raw preserva o payload, mas o mapeamento final dos campos CCEE para a tabela tratada/fato precisa ser validado com a resposta real. A carga completa das fatos, o relatório de antes/depois e o dashboard ainda precisam ser concluídos e testados pela equipe.
