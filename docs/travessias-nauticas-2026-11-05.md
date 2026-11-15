# MaraPass — pesquisa e primeiro traçado aquaviário

Pesquisa conferida em 05/11/2026. Amplia a versão 14 no mesmo projeto. Preserva 4.276 IDs e a camada de 62 referências insulares.

## Resultado e uso

Existe mapeamento público útil. A ANTAQ disponibiliza linhas de travessia outorgadas em KML e shapefile (edição 06/05/2025), instalações portuárias outorgadas (mesma edição) e Vias Interiores Economicamente Navegadas (VEN 2022). Essas bases têm escopos distintos: não equivalem a todas as linhas locais, excursões turísticas ou rotas operacionais atuais.

O ZIP de travessias foi baixado e inspecionado: 93 feições nacionais, quatro com município de origem ou destino no Maranhão. A feição `idl_vessia=300044`, `idantaq=175`, documenta Araioses–Canárias / Ilha Grande–Tatus. A geometria tem 18 vértices. A ordem espacial começa no lado Tatus (-41.83015, -2.831645) e termina no lado Canárias (-41.846466, -2.767181). A extração preserva todos os vértices da fonte, sem completar o desenho com segmentos inventados. Esses extremos não substituem levantamento do cais ou acesso rodoviário.

O registro ANTAQ do primeiro termo aditivo à autorização 1.437, publicado em 10/07/2024, documenta ligação Canárias–Tatus e tempo médio de 20 minutos no esquema do ato. O aplicativo apresenta esse tempo como documental, não ETA, programação de hoje ou promessa comercial. Não se publica documento pessoal do operador na ficha.

O suplemento `nautical_connections.json` registra edição, URL de origem, download e SHA256 do ZIP, IDs oficiais, geometria, extremos, status `documented_reference`, `operationallyVerified=false`, uso `planning_only`, fonte da autorização e associação somente à ilha Canárias. A coordenada representativa da ilha continua separada do extremo da travessia.

## Infraestrutura identificada

| Local | Evidência | Limite da evidência |
|---|---|---|
| Canárias e Carnaubeira, Araioses | DNIT, conclusão de recuperação, 05/11/2025 | Não prova funcionamento ou serviço no dia da consulta |
| Cururupu e Coroatá/Palmeirândia | DNIT, conclusão de recuperação, 06/05/2026 | Não associa automaticamente cada cais às ilhas |
| Cateauá/Porto Rico, Guimarães, Cururupu, Canárias | AHINOR/DNIT, contratação, 14/12/2016 | Registro histórico; não cadastro operacional atualizado |
| 11 municípios maranhenses | Relatório CODOMAR de 2007 menciona implantação pela AHINOR | Sem inferência de gestão atual |

A documentação consultada vincula a AHINOR ao DNIT e, historicamente, à CODOMAR. Não há comprovação nesta pesquisa de que a Codevasf tenha executado o conjunto desses atracadouros; não são tratados como a mesma instituição. Construtor, proprietário, mantenedor, operador, fiscalização marítima e regulação de transporte devem ter campos separados.

## Carrapatal e Lençóis

Carrapatal: boletim do Tribunal Marítimo, edição 23 de 15/04/2024, descreve uma ocorrência de 30/08/2014 com viagem São José de Ribamar–Carrapatal. É evidência histórica da ligação, não oferta turística, rota GPS ou confirmação de cais/serviço em 2026. O aplicativo informa a pendência, aponta a fonte e não desenha um trajeto presumido a partir de Porto da Roça ou outro cais próximo.

Lençóis: estudo publicado em 2014, com entrevistas de 2011–2013, documenta embarques por Apicum-Açu e Cururupu. O ano da pesquisa é indispensável. Não se atribuem os tempos ou a predominância daquele estudo ao serviço atual. Não há geometria importada para essa ilha nesta entrega.

## Marinha e licença

CHM/DHN disponibiliza cartas, roteiros e outros produtos. A página de cartas raster informa que uso comercial demanda autorização e eventual acordo com a EMGEPRON. Também restringe GeoTIFF a fins acadêmicos e proíbe seu uso como auxílio à navegação. Portanto, nenhuma carta foi copiada, vetorizada ou incorporada ao MaraPass. São fornecidos links oficiais. Verificar cobertura, escala, correções e direitos para cada produto antes de contratar integração.

A página da CPMA lista NPCP e alteração pela Portaria 102/2026. Não se declara certificação, homologação, autorização de rota ou responsabilidade operacional da Capitania por um trajeto cadastrado no MaraPass.

## Experiência publicada

Ilhas do litoral → Travessias e pontos de embarque; também há botão na ficha de cada ilha. Visão por ilha limita a associação aos dados documentados. Canárias abre mapa próprio com linha aquaviária tracejada e extremos numerados, fonte e ressalva visível de planejamento. Não há botão de condução de embarcação, áudio de manobra, cálculo por linha reta, extrapolação por rio mais próximo ou rota de carro para centroide insular. Os serviços rodoviários anteriores continuam separados.

## Próxima validação operacional

Solicitar dados ao DNIT/MA (DAQ), prefeituras/gestores dos cais, CPMA, regulador estadual e ANTAQ conforme sua competência. Campos: ID e coordenadas do cais, administração e contato institucional, acesso terrestre, acessibilidade, linha de passageiros ou passeio, operador, registro aplicável, geometria GPX/KML autorizada, data e condições do levantamento, pontos de parada, restrições de maré/calado, janela operacional, duração observada, horários, preço, retorno, fonte e próxima revisão. A confirmação documental não é validação hidrográfica.

Estados editoriais propostos para painel: identificado → documentado → verificado com operador → publicado para planejamento; suspenso quando houver restrição. Conservar versão e revisor. Trilha GPS enviada por parceiro permanece privada para revisão até autorização de uso e verificação; não habilita navegação automaticamente. Esta entrega não altera o backend de publicação, permissões ou histórico do projeto.

## Fontes

- https://www.gov.br/antaq/pt-br/central-de-conteudos/informacoes-geograficas
- https://www.gov.br/antaq/pt-br/central-de-conteudos/Linhasdetravessias06052025.zip
- https://sophia.antaq.gov.br/Terminal/Acervo/Detalhe/36910
- https://www.gov.br/dnit/pt-br/assuntos/noticias/dnit-conclui-reforma-dos-atracadouros-hidroviarios-de-canarias-e-carnaubeira-no-maranhao
- https://www.gov.br/dnit/pt-br/assuntos/noticias/no-maranhao-dnit-conclui-recuperacao-de-atracadouros-hidroviarios-em-cururupu-e-palmeirandia
- https://www.gov.br/dnit/pt-br/assuntos/noticias/ahinor-contrata-obras-em-atracadouros-no-maranhao
- https://www.gov.br/portos-e-aeroportos/pt-br/centrais-de-conteudo/relatoriogestao-2007-pdf
- https://www.marinha.mil.br/chm/dados-do-segnav/cartas-raster
- https://www.marinha.mil.br/chm/dados-do-segnav-publicacoes/roteiros
- https://www.marinha.mil.br/cpma/node/131
- https://www.marinha.mil.br/tm/sites/www.marinha.mil.br.tm/files/boletim-de-acidentes/23.pdf
- https://periodicos.unifesp.br/index.php/ecoturismo/article/view/6415

## Validação da entrega

63 testes Flutter passaram; compilação web de produção concluída. Conferência no navegador: abertura do diretório, carga do suplemento, ficha de Tatus–Canárias, rótulos de tempo documental e pendência operacional, abertura do mapa com linha tracejada e extremos 1/2. Dados anteriores de pontos, ilhas, altitude e relevo preservados byte a byte. O fundo é a cartografia simplificada de referência do aplicativo, sem todos os canais e sem batimetria; não constitui carta náutica. Navegação de campo, operação atual e acessos por terra não foram validados.
