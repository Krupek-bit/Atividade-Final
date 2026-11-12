# Data Warehouse — Campo Real Energia

Projeto acadêmico de construção de um Data Warehouse para a empresa fictícia Campo Real Energia.

## Objetivo

Construir um fluxo de dados desde as bases operacionais e fontes externas até um modelo dimensional (star schema), permitindo analisar geração de energia, preços horários do PLD, paradas de usinas e qualidade dos dados.

## Tecnologias previstas

- MySQL 8
- Python
- pandas
- API de dados abertos da CCEE
- Uma fonte complementar (Open-Meteo, ONS ou INMET)
- Power BI ou Tableau

## Estrutura do repositório

```text
campo_real_energia/
├── README.md
├── .gitignore
├── requirements.txt
├── docs/
│   └── enunciado_trabalho.pdf
├── sql/
│   ├── origem/
│   │   └── campo_real_energia.sql
│   └── warehouse/
├── python/
│   ├── extracao/
│   └── qualidade/
└── dashboard/
```

## Como começar

1. Instale o MySQL 8.
2. Abra `sql/origem/campo_real_energia.sql` no MySQL Workbench ou DBeaver.
3. **Atenção:** o script começa com `DROP DATABASE IF EXISTS campo_real_energia`. Isso apaga o banco anterior com esse nome. Execute somente se puder recriá-lo.
4. Leia o enunciado em `docs/enunciado_trabalho.pdf`.
5. Desenvolva os scripts Python de extração e qualidade nas pastas correspondentes.
6. Crie os scripts DDL e de carga do Data Warehouse em `sql/warehouse/`.
7. Salve o arquivo final do Power BI ou Tableau em `dashboard/`.

## Banco de origem

O script disponibilizado cria as tabelas operacionais da Campo Real Energia e gera dados simulados de medição e paradas. O PLD deve ser obtido/carregado conforme as instruções do trabalho. O banco de origem ainda não é o Data Warehouse.

## Status dos entregáveis

- [x] Enunciado do trabalho incluído.
- [x] Script SQL do banco de origem incluído.
- [ ] Extração automática do PLD horário da CCEE via API.
- [ ] Extração de uma fonte complementar.
- [ ] Profiling e regras de qualidade em Python.
- [ ] Tabela de métricas de qualidade.
- [ ] Modelagem dimensional e scripts SQL do Data Warehouse.
- [ ] Documento de modelagem e diagrama star schema.
- [ ] Relatório antes x depois da limpeza.
- [ ] Dashboard Power BI ou Tableau.

## Fontes

- CCEE — Dados Abertos: https://dadosabertos.ccee.org.br/dataset/pld_horario
- Open-Meteo — Historical Weather API: https://open-meteo.com/en/docs/historical-weather-api
- ONS — Dados Abertos: https://dados.ons.org.br/
- INMET — Dados históricos: https://portal.inmet.gov.br/dadoshistoricos

Consulte o enunciado para os requisitos completos e para as regras de atribuição das fontes.
