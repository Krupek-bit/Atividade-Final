# Decisões iniciais de modelagem

## Grãos declarados
- `fato_geracao`: uma linha por usina e hora de medição.
- `fato_pld`: uma linha por submercado, hora e versão do preço.
- `fato_clima`: uma linha por usina e hora de observação meteorológica.

## Dimensões e histórico
A dimensão tempo é horária para permitir o cruzamento com geração e PLD. A dimensão usina adota SCD Tipo 2 como proposta inicial para preservar alterações históricas de nome, potência e situação. As dimensões possuem chaves substitutas; a chave 0 representa o membro desconhecido.

## Granularidade
A geração é registrada por usina/hora e o PLD por submercado/hora. A associação é feita pelo submercado da usina e pelo mesmo instante. O clima é associado à usina pelas coordenadas cadastradas. A distância entre a coordenada da usina e o ponto meteorológico deve ser considerada na análise.

## Matriz de barramento
| Processo | Tempo | Usina | Submercado | Fonte |
|---|---|---|---|---|
| Geração horária | X | X | X | X |
| PLD horário | X | | X | |
| Clima horário | X | X | | |

Os campos reais do payload CCEE precisam ser inspecionados antes de desenvolver o mapeamento para a camada tratada e para `fato_pld`.
