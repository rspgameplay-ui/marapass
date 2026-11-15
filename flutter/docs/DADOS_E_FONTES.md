# Dados e fontes — 30/10/2026

A base do mapa não é uma cópia de Google Maps, Mapbox ou Waze. Ela combina fontes públicas identificadas e um catálogo próprio, com campos de proveniência. Não foram extraídos contatos privados de parceiros nem atribuídas ofertas às empresas externas.

## Base territorial

- **217 municípios**: nomes, códigos e áreas da Malha Municipal IBGE 2025, publicada em 2026. Endereço: https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2025/UFs/MA/MA_Municipios_2025.zip
- **Sedes municipais**: IBGE, Localidades do Brasil / Censo 2022, publicação de 2025. Endereço: https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/localidades/Localidades_do_Brasil/2022/Localidades_Brasil_gpkg.zip
- O arquivo de localidades contém dois registros de Cidade em São Luís. O importador mantém o registro classificado como Capital Estadual e elimina a duplicidade pelo código municipal.
- A geometria SIRGAS 2000 (EPSG:4674) foi transformada para WGS84 (EPSG:4326). A vinculação dos pontos usa os polígonos originais. Somente a geometria de exibição é simplificada em 0,002 grau, com preservação topológica; não deve ser usada para demarcação legal.
- Regiões Geográficas Imediatas/Intermediárias são classificações do IBGE, distintas dos polos turísticos. A composição turística oficial, incluindo Balaiada, continua sujeita à homologação. Os agrupamentos editoriais anteriores são mantidos onde já existiam, com essa distinção.

## Pontos nomeados

Uma consulta Overpass limitada ao Maranhão retornou **3.997 registros** nomeados de turismo, alimentação, hospedagem, patrimônio, artesanato e serviços úteis. A base OSM da resposta é `2026-10-30T10:51:51Z`.

- **3.991** foram vinculados a exatamente um município por interseção espacial com a malha original.
- **6** ficaram de fora por falta de uma vinculação municipal única. Não foram deslocados para a cidade mais próxima.
- Há registros da extração em **146 municípios**. Em **71**, esta consulta não encontrou os tipos nomeados selecionados. Isso não comprova inexistência de estabelecimentos ou atrativos.
- O pacote contém **4.217 pontos**: 217 sedes, 3.991 registros OSM e 9 referências editoriais anteriores não duplicadas pelo critério de nome e proximidade. Não são 4.217 atrativos homologados.
- Endereços, telefones, sites e horários são importados apenas quando presentes nas tags públicas. Campos ausentes são indicados na ficha. Dados colaborativos podem estar desatualizados; não são avaliações nem certificação MaraPass.
- A posição de um nó ou o centro geométrico de uma área não comprova a entrada acessível. Todos os registros OSM importados são apresentados como referências, sem selo de parceiro e sem cupons.

`assets/data/source_manifest.json` registra contagens, data e SHA-256 dos insumos. `docs/cobertura_municipal.csv` registra os 217 municípios e as lacunas. `scripts/import_maranhao.py` documenta a transformação, a preservação de IDs anteriores e a vinculação geográfica. Não há extração automática no aplicativo nem dependência de Overpass por visita.

## Mapas, rotas e licenças

- Dados OSM: © OpenStreetMap contributors, ODbL 1.0. https://www.openstreetmap.org/copyright e https://opendatacommons.org/licenses/odbl/1-0/
- Estilo e tiles: OpenFreeMap / OpenMapTiles / OpenStreetMap. Atribuição visível no mapa. https://openfreemap.org/ e https://openfreemap.org/tos/
- O mapa principal usa renderização vetorial em Flutter, sem exigir WebGL do navegador. MapLibre e Google nativo continuam como adaptadores adicionais.
- O servidor público de tiles raster OSM não é usado na versão final: na conferência, devolveu imagens de bloqueio. O aplicativo não altera identidade ou cabeçalhos para contornar esse bloqueio.
- Rotas: OSRM / FOSSGIS, dados OSM. https://routing.openstreetmap.de/about.html e https://project-osrm.org/docs/v5.22.0/api/
- As rotas têm geometria e manobras retornadas pelo serviço. Nenhuma reta é convertida em trajeto viário. O encaixe permitido na rede é de até 500 m; o aplicativo alerta sobre o acesso final quando o afastamento é relevante.
- O cliente evita chamadas simultâneas e mantém intervalo mínimo de 1,1 segundo. Recálculo automático exige três posições precisas fora da rota e respeita intervalo de 30 segundos. Isso limita a prévia individual; não substitui cotas globais no backend de produção.
- As posições usadas para cálculo são enviadas ao serviço de rotas, que tem sua própria política de logs/privacidade. O aplicativo não armazena histórico de trajetos. O acompanhamento GPS é encerrado ao sair da tela ou colocar o aplicativo em segundo plano.
- Google/Mapbox exigem seus contratos, credenciais e restrições específicos. Não foram simuladas credenciais, dados de trânsito, alertas colaborativos, interdições, limites de velocidade ou mapas de satélite desses serviços.

Os dados derivados do OpenStreetMap distribuídos neste pacote estão sob ODbL. Não há cópia da licença desses dados para o código do aplicativo: licenças de software e de bases de dados são distintas. A distribuição e futuras atualizações da base devem preservar atribuição e as obrigações da ODbL.

## Antes do uso em produção

Confirmar entradas e condições de acesso, horários e contatos com responsáveis; completar os 71 municípios sem pontos nesta extração; revisar categorias do mapeamento colaborativo. Configurar hospedagem ou provedor de rotas com capacidade e contrato apropriados, quotas globais e privacidade. Realizar testes de campo em Android/iPhone e diferentes condições de GPS. Não apresentar esta prévia como substituta já homologada de um navegador rodoviário comercial.
