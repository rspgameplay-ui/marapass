# MaraPass — revisão municipal e gravação de percursos

Conferência editorial: 05/11/2026. Base: versão 11 do projeto existente. Mesma identidade e audiência de acesso.

## Conteúdo e navegação

Preservados os 4.217 registros, IDs e coordenadas existentes, incluindo 50 registros de Santo Amaro do Maranhão e 6 de Primeira Cruz. Oito fichas receberam revisão editorial. Categorias corrigidas: Junco, duas referências de Lagoa Bela, Parque Nacional e Cassó passam a Natureza. As duas referências Lagoa Bela foram mantidas: não há evidência suficiente para tratá-las como duplicação.

Santo Amaro: fichas de Betânia, Emendadas, Gaivota e Junco complementadas; guia municipal com Betânia, Andorinha, Emendadas, Junco e Rancharia. Primeira Cruz: Cassó com referência da Setur; guia com Lagoa da Areia/Campo Novo, Areinha, Pouso dos Guarás e Mairi. Novos circuitos não recebem coordenadas inventadas nem marcadores de acesso presumidos. A data de conferência do texto não representa verificação de campo da posição ou confirmação de operação de estabelecimentos.

Nas referências naturais selecionadas, o comando Planejar visita substitui a rota automática de carro e solicita a confirmação de embarque, estacionamento ou encontro. O bloqueio também cobre autoPlan; as cidades e os estabelecimentos comuns mantêm o planejador rodoviário. Regra conservadora até cadastrar pontos de acesso confirmados. Cupons e parceiros mantêm os critérios de publicação existentes; nenhuma parceria foi presumida a partir de diretórios.

Guias disponíveis nas fichas e nos resultados quando o município está filtrado. Explorar locais deste município limpa filtros anteriores, seleciona a cidade e centraliza o mapa.

## Percursos — piloto em primeiro plano

Mais → Gravar meu percurso. GPS com precisão de até 50 m, filtragem de pontos antigos e saltos, pausa/retomada em segmentos separados, distância e tempo ativo, rascunho recuperável e percursos salvos localmente. Saída da página ou perda de atualizações pausa a gravação. Não há gravação em segundo plano, sincronização em nuvem, exportação, publicação ou integração Strava. Dados ilegíveis são preservados e bloqueiam sobrescrita. Limpar o armazenamento do navegador pode apagar os percursos. O traçado registra movimento; não certifica acesso, segurança ou autorização da rota.

## Fontes consultadas

As páginas municipais do ICMBio indicam atualização em 14/08/2026; conferidas em 05/11/2026.

- Santo Amaro: https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/paginas-site-parna-dos-lencois-maranhenses-ma/santo-amaro
- Primeira Cruz: https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/paginas-site-parna-dos-lencois-maranhenses-ma/primeira-cruz
- Regras de travessia: https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/trekking-travessia-dos-lencois
- Cassó, referência institucional anterior: https://turismo.ma.gov.br/noticias/agua-doce-tutoia-e-primeira-cruz-recebem-obras-do-turismo

Coordenadas e demais registros: origem anterior preservada, com atribuição IBGE/OpenStreetMap. Informações de segurança são orientativas; não representam certificação ISO do aplicativo ou de prestadores.

## Validação

51 testes Flutter passaram. Incluem catálogo/painel equivalentes, quantidade de registros e códigos municipais, pesquisa, favoritos, rascunhos/publicação, navegação, benefícios, filtros dos dois municípios, telas com 320 px e texto ampliado, GPS impreciso, cancelamento e recuperação de percursos. Build web de produção em Flutter. Navegação física com GPS e comportamento em aparelhos reais ainda precisam de teste de campo. Google Maps/Places não foi ativado nesta revisão.

Conferência visual no navegador: pesquisa Junco → Planejar visita → guia de Santo Amaro; aplicação do filtro com 50 registros; pesquisa Primeira Cruz com 6 registros → ficha completa → guia municipal; Mais → Gravar meu percurso. A captura `primeira-cruz-preview.jpg` documenta a ficha complementar. Após a conferência foi corrigido o atalho Waze nas referências naturais e acrescentado teste de regressão.
