# MaraPass — ilhas costeiras e estuarinas

Entrega de 05/11/2026, sobre a versão 13 com relevo e altitude. Mesmo projeto, identidade visual, acesso e dados consolidados.

## Conteúdo

62 referências insulares, com contornos para 59 registros e três marcadores sem contorno individual importado. São 59 IDs novos e três reaproveitados: Ilha dos Lençóis, Ilha do Medo e Ilha do Cajoeiro (Tutóia). Os 4.217 registros originais, suas coordenadas, o complemento de altitudes e a camada de relevo foram preservados em seus arquivos originais. Catálogo combinado: 4.276 IDs únicos. É uma base inicial, sem representar o inventário completo das ilhas do Maranhão.

Exemplos: Ilha de São Luís / Upaon-Açu / Ilha do Maranhão, Tauá-Mirim, Curupu, Cajual, Caranguejos, Santana, Carrapatal, Caju, Canárias, Maiaú, Caçacueira, Mangunça, Mirinzal e Lençóis. Regiões de exploração editorial: Reentrâncias Maranhenses, Golfão Maranhense, Lençóis e baía de Tubarão, Delta das Américas. Não são uma redefinição dos polos oficiais.

## Experiência

Mais opções → Ilhas do litoral. Pesquisa por nome, município ou referência alternativa; filtro regional; seleção abre a ficha ligada ao mapa. Ver ilhas no mapa ativa apenas referências insulares e usa a camada de ruas para mostrar os contornos. O botão de fechar o filtro recupera os demais lugares. Busca geral, favoritos, filtros e consulta de altitude continuam disponíveis. Empresa que possui “ilha” no nome não é classificada automaticamente como ilha.

A busca recebe prioridade na tela pequena: ao digitar, os textos introdutórios recolhem e os resultados aproximam-se do campo. O diretório foi verificado em 320 px e com texto ampliado. Upaon-Açu também aparece no filtro das quatro cidades que abrange: São Luís, São José de Ribamar, Paço do Lumiar e Raposa.

Os contornos são de referência cartográfica, simplificados para visualização, não limites jurídicos ou levantamento atual de campo. Novos pontos com geometria usam ponto interno representativo do contorno; os três marcadores anteriores foram preservados. O ponto não indica porto ou desembarque. Campos de acesso, horário ou preço não foram inventados. Novos marcadores sem amostra correspondente continuam mostrando altitude não disponível.

## Fontes

Cartografia: OpenStreetMap, consulta de topônimos `place=island|islet` e recuperação dirigida dos objetos identificados pela API oficial. Os contornos e pontos foram cruzados com a malha municipal IBGE do projeto. O catálogo registra fonte, versão e data do objeto quando disponíveis; a data de conferência não representa data de medição da costa.

- https://www.openstreetmap.org/copyright — © OpenStreetMap contributors, ODbL.
- https://agem.ma.gov.br/programas-ou-campanhas/mapas-grande-ilha — organização municipal da Grande Ilha.
- https://portais.ufma.br/PortalUfma/paginas/noticias/noticia.jsf?id=8064 — referência histórica para topônimos do arquipélago de Maiaú, sem tratar infraestrutura descrita em 2010 como atual.
- https://turismo.ma.gov.br/programas-ou-campanhas/polo-delta-das-americas
- https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/apa-delta-do-parnaiba/informacoes-sobre-visitacao-apa-delta-do-parnaiba/area-de-protecao-ambiental-delta-do-parnaiba
- https://mapcarta.com/pt/Ilha_das_Can%C3%A1rias — referência GeoNames 3403422 para Canárias, com atribuição GeoNames CC BY; localização não validada como desembarque.

O complemento `coastal_islands.json` documenta referências pendentes. Cangatá possui topônimo duplicado; São Lucas é tratado como referência de comunidade de São João Mirim, sem criar uma ilha independente. Maré e Santa Rosa ficaram pendentes pela divergência entre geometria OSM e malha municipal. Os dois contornos OSM com o nome Lençóis foram associados à ficha anterior, com nota de identificação local pendente, sem duplicar o cadastro.

`flutter/scripts/build_coastal_islands.py <diretório de objetos OSM JSON>` reproduz o suplemento a partir dos arquivos cartográficos, sem enviar coordenadas privadas, posições de turistas ou dados de parceiros. Não existe serviço de geocodificação genérico novo no aplicativo.

## Visitação e navegação

Toda referência insular usa Planejar visita. Há proteção contra rota de carro automática e contra o atalho Waze para o marcador da ilha. Para dirigir na ilha de São Luís, escolha endereço ou estabelecimento específico. A ficha orienta confirmar embarque, desembarque, retorno, maré, tempo, regularidade da embarcação e coletes, respeitando comunidades, áreas protegidas e propriedades. A presença no catálogo não representa autorização de visita. Não foram calculadas rotas náuticas ou inferidos acessos pelo desenho do contorno.

## Validação

60 testes Flutter passaram, incluindo regressões anteriores, preservação de IDs, atualização do catálogo, filtro insular, aliases, abrangência municipal de Upaon-Açu, seleção em celular com texto ampliado e bloqueio de rota rodoviária automática para ilhas. Compilação web de produção e conferência visual antes da publicação. Navegação de campo e acessos por embarcação não foram validados.

Conferência no navegador da versão compilada: menu Ilhas do litoral, ativação da camada com 62 referências e grupos numéricos, busca Canárias com resultado único, abertura da ficha com fontes e Planejar visita, e retorno ao mapa na localização selecionada. O mapa de referência e os contornos foram renderizados; a carga de mosaicos externos não foi confirmada neste ambiente.
