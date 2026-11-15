# MaraPass — altitude e relevo

Entrega de 05/11/2026 sobre a versão municipal anterior, sem mudança de IDs, coordenadas, descrições, filtros, parceiros, cupons ou permissões.

## Funcionalidade

Mais opções → Escolher mapa → Relevo e altitude. A camada regional mantém os marcadores e as ações do mapa, centraliza uma vista estadual e funciona com os arquivos embarcados. Cores suaves mostram altitude; sombreamento ajuda a ler o terreno. Toque na legenda para fontes e limites. A camada é ocultada acima do zoom 11 para evitar aparência de detalhe inexistente.

Ver detalhes de um local → Altitude estimada. Há 4.217 amostras para os 4.217 marcadores públicos da base, incluindo as 217 sedes municipais. O valor é do marcador, não da extensão do município. SRTM de aproximadamente 30 m, datum vertical EGM96, interpolação bilinear via Open Topo Data, consulta 05/11/2026. Números inteiros são aproximações; resolução horizontal não é precisão vertical. Zero é válido; ausência de amostra não vira zero.

Uma amostra só aparece quando ID e coordenadas coincidem. Alterações de posição invalidam o valor; pontos novos ficam sem altitude até nova importação. A aplicação não consulta altitude de posições GPS ou percursos pessoais, nem transmite dados privados a provedores topográficos. A importação restringe-se ao catálogo público embarcado e envia somente coordenadas públicas, sem nomes ou IDs. O script exige fontes públicas reconhecidas e ausência de parceiros privados; a consulta inicial em lote foi bloqueada pela revisão automática e só prosseguiu após comprovação e restrição explícita da origem pública.

## Camada e reprodução

`flutter/scripts/build_terrain_overlay.py`: download de 48 Terrain Tiles públicos Mapzen, formato Terrarium, zoom 8; decodificação, cores por altitude, sombreamento suave, máscara estadual IBGE e PNG Web Mercator. Espaçamento aproximado de 610 m. Manifesto com limites, data, fonte e SHA-256 do PNG. Não é levantamento recente, curvas de nível nem classificação geomorfológica oficial.

`flutter/scripts/import_elevations.py`: importação retomável das amostras SRTM30m, no máximo 90 posições por requisição, intervalo mínimo de 1,1 s, limite público de 100 posições/requisição e 1 requisição/s respeitado. As respostas são conferidas contra as coordenadas enviadas e persistidas como complemento, sem alterar o catálogo principal. Reexecutar com consultas existentes não atualiza automaticamente os registros; a renovação deve ser uma operação editorial controlada.

## Fontes e atribuição

- Referência enviada pelo proprietário: https://pt-br.topographic-map.com/map-l2c9m/Maranh%C3%A3o/ . Mantida como link de consulta. Estatísticas gerais e imagens desse serviço não foram copiadas para a base MaraPass.
- API / dataset: https://www.opentopodata.org/datasets/srtm/ e https://www.opentopodata.org/ . SRTM V3, missão original em 2000. A consulta em 2026 não representa aquisição em 2026.
- Dados raster: https://registry.opendata.aws/terrain-tiles/ . Mapzen Terrain Tiles; global SRTM/GMTED2010 courtesy of the U.S. Geological Survey. Atribuição: https://github.com/tilezen/joerd/blob/master/docs/attribution.md . Atribuição Mapzen/USGS exibida na legenda.
- Datum e época: https://www.usgs.gov/centers/eros/science/usgs-eros-archive-digital-elevation-shuttle-radar-topography-mission-srtm
- Limite estadual: IBGE / malha 2025 já utilizada pelo projeto.

## Limitações de uso

SRTM pode refletir vegetação e construções. Dunas, lagoas e acessos dos Lençóis podem ter mudado desde a aquisição. A camada não estima enchentes, dificuldade, esforço, acessibilidade, ganho de elevação de percurso nem segurança. Regras de transporte credenciado e planejamento de visita da entrega anterior continuam vigentes. Não há integração automática com topographic-map.com nem importação Strava.

## Validação da entrega

55 testes Flutter passaram: regressões anteriores, cobertura dos 4.217 registros, coordenadas correspondentes, zero/ausência de amostra, invalidação por edição, ficha e camada em 320 px com texto ampliado, e seleção de mapa. O seletor recebeu rolagem após o teste encontrar falta de espaço vertical. Build web de produção, sem novas dependências de aplicação.

Conferência visual no navegador concluída: seleção Relevo e altitude, legenda e recorte estadual; busca Santo Amaro → ficha → expansão da altitude, valor e fontes. Captura `relevo-preview-20261105.jpg`. Estimativas pontuais das sedes: Santo Amaro ≈3 m e Primeira Cruz ≈12 m, nas coordenadas do catálogo. Não são altitudes oficiais médias ou extremas dos municípios.
