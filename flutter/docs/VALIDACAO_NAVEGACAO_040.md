# Validação 0.4.0 — 02/11/2026

- Dependências recuperadas nas versões fixadas do pubspec.lock, com SHA256 conferido.
- Ferramentas executadas com CI=true e FLUTTER_SUPPRESS_ANALYTICS=true; sem consulta de detecção de nuvem e sem telemetria.
- flutter test --no-pub: 23 testes aprovados nesta reconstrução, incluindo início e parada da simulação sem GPS.
- Código da central editorial e banco preservados; não houve migração nem gravação de pontos fictícios no catálogo compartilhado.
- Limitações: base detalhada local restrita aos recortes documentados; navegação física Android/iOS, qualidade do GPS e voz em aparelhos específicos ainda requerem homologação. Trânsito ao vivo e alertas de comunidade não estão incluídos.

- flutter build web --release: concluído.
- Conferência no navegador, viewport 390x844: cartografia visível; rota São Luís–Barreirinhas calculada (255 km na consulta); simulação avançou com atualização de manobras e distância restante.
