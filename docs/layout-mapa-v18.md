# Tela Mapa — layout compacto

Busca, região e menu compartilham a mesma superfície. A segunda linha contém categorias com rolagem horizontal. Sem degradê de cobertura. A pílula de clima de 44 px abre o painel completo já existente; os dados e o serviço não foram alterados.

Gaveta: mínimo/inicial de 80 px; snap intermediário em 50%; expandida em 100% da área útil acima da navegação. A alça e a quantidade aparecem no estado recolhido. Título e cards são apresentados ao expandir. Localização e atribuição acompanham a altura da gaveta, com áreas de toque de 44 px. Fontes e licenças continuam acessíveis em “Fontes e atribuição do mapa”. A navegação inferior mantém Mapa, Lugares, Salvos e Guias.

Medição: o teste map_layout_test usa viewport de 390 × 844, mede as superfícies de busca, categorias e clima e desconta a gaveta e os controles de 44 px. Percentual corresponde à área útil da tela Mapa, excluindo a navegação inferior e barras externas do sistema/navegador. Não é uma medição de tela inteira incluindo a interface do ChatGPT. Texto ampliado e teclado aberto podem reduzir o espaço livre em favor da acessibilidade.

Não há mudança no catálogo, critérios de agrupamento, busca, regras de filtros, GPS, serviço meteorológico ou APIs. Reutiliza o projeto Flutter e as configurações existentes. Compilação: na pasta flutter, executar flutter pub get --enforce-lockfile, flutter test e flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/catalogo.json; depois python scripts/prepare_web_output.py. Copiar build/web para dist sem remover as páginas administrativas existentes.

Validação: 69 testes Flutter aprovados, incluindo busca, filtros, retorno do filtro de ilhas, favoritos, clima e expansão da gaveta. O cálculo automatizado registrou 75,7% de área livre sobre a superfície do mapa em uma janela de 390 × 844 (viewport do mapa: 390 × 774), descontando retângulos completos dos controles, inclusive áreas de toque transparentes. Não inclui a navegação inferior fixa no denominador.
