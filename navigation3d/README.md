# Navegação 3D MaraPass

O Flutter mantém o cálculo OSRM, a simulação, o GPS, a voz, o catálogo, os cupons e os painéis. Durante a navegação web, um iframe da mesma origem carrega a vista MapLibre. A ponte repassa a geometria da rota, a posição e o rumo, o progresso e os POIs do catálogo. A vista 2D continua disponível em caso de falha ou escolha do usuário. O iframe não guarda posições e o modo de simulação usa as posições fictícias do Flutter.

| Camada | Repositório | Pacote ou fonte |
| --- | --- | --- |
| Renderização / câmera | https://github.com/maplibre/maplibre-gl-js | `maplibre-gl` |
| Cartografia | https://github.com/hyperknot/openfreemap | Tiles OpenFreeMap / OpenStreetMap via HTTP |
| Satélite | https://github.com/nasa-gibs/onearth | NASA GIBS Blue Marble em WMTS, nível original máximo 8 |
| Rota e ETA | https://github.com/Project-OSRM/osrm-backend | OSRM já integrado ao Flutter, sem pacote npm |
| Interface do mapa | https://github.com/facebook/react, https://github.com/tailwindlabs/tailwindcss | `react`, `react-dom`, `tailwindcss`, `@tailwindcss/vite`, `lucide-react` |

O estilo em `src/marapass-style.json` adapta OpenFreeMap Liberty e mantém a câmera inclinada e as extrusões dos edifícios. O terreno elevado está desativado para manter vias e rota no mesmo plano do mapa. O carro é um marcador desenhado em CSS, com rumo e tamanho legível em qualquer zoom. Se a vista 3D não confirmar a renderização da rota e das vias, o Flutter abre a vista 2D. O satélite regional é ampliado pelo renderizador e não tem detalhe de rua.

As fichas de POI mostram a distância adiante na rota, sem estimar um desvio por vias desconhecidas. A busca de origem e destino continua usando o catálogo do MaraPass.

## Build

Execute `npm ci` e `npm run build` em `navigation3d/`. Copie o conteúdo de `navigation3d/dist/` para `flutter/web/navigation-3d/` antes de compilar o Flutter. O bundle da camada 3D é carregado somente na navegação ativa, em navegadores com WebGL 2.
