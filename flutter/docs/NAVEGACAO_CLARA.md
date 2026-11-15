# MaraPass 0.4.0 - Navegação clara

Interface em Flutter com planejamento interno, origem pesquisável, alternativas rodoviárias, instruções em português, controles de voz e recentralização. A simulação usa geometria calculada, não pede GPS, não registra deslocamentos reais e permanece identificada na tela.

A cartografia de referência foi extraída do OpenStreetMap em 2026-11-02T01:49:04Z via Overpass: vias principais no Maranhão e vias locais nos recortes (-2.62,-44.36,-2.47,-44.12) e (-2.79,-42.87,-2.72,-42.78), com contorno IBGE. Não é cobertura completa de ruas dos 217 municípios. O aplicativo não depende das imagens públicas que foram bloqueadas durante a conferência. Dados OSM sob ODbL, https://www.openstreetmap.org/copyright.

O cálculo e recálculo de rotas usam OSRM/FOSSGIS e exigem conexão. Sem trânsito ao vivo, radares ou alertas Waze. O mapa vetorial online permanece opcional em aparelhos compatíveis. GPS, voz e operação em aparelho físico ainda precisam de homologação. Uso em primeiro plano; ocultar o aplicativo pausa a navegação.

Para experimentar: abra o endereço publicado com ?route=barreirinhas, aguarde o cálculo e toque em Simular percurso sem GPS. O painel editorial existente foi preservado; não houve migração de banco nem publicação de pontos fictícios.
