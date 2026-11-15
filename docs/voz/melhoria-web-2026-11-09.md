# Voz web — 09/11/2026

## Alterações
- Adapter carregado antes do Flutter em `flutter/web/index.html` e `dist/index.html`.
- `flutter/web/voice/recognition_adapter.js` (cópia idêntica em `dist/voice/`): compatibilidade com os construtores padrão e prefixado do navegador. O plugin compilado verificava ambos mas instanciava apenas webkitSpeechRecognition.
- Português brasileiro explícito, até três alternativas solicitadas ao provedor (preservada sua primeira escolha; sem troca silenciosa de destino).
- Segmentos parciais/finais reunidos antes da interpretação existente, com normalização de linguagem natural: me leva pra, gostaria de ir, onde fica, não eu falei. Variações de São Luís e Olho d’Água. Na busca web publicada, Olho d’Água usa trecho distintivo contíguo e pode retornar praia e estabelecimentos homônimos: o usuário escolhe o destino. Correções iniciam nova consulta; não há herança conversacional de filtros nesta adaptação. Data “depois de amanhã” convertida pela data civil de Fortaleza.
- Escuta limitada a 25 segundos, pausa de cinco segundos após resultado; cancelamento e erros limpam temporizadores. Sem escuta automática, gravação ou persistência de transcrições.
- `flutter/test/web/recognition_adapter.test.cjs`: 18 testes de comandos, fragmentos, datas, construtores, permissões, cancelamento, eventos vazios e instalação idempotente.

## Escopo e limites
É uma atualização da versão web hospedada. O binário Flutter e a interpretação Dart existente são preservados, inclusive confirmação de destino, dados reais e regras de cupons. Não houve compilação Android/iOS nem nova compilação Dart; o módulo web é carregado antes do binário e será preservado em novas compilações pelo arquivo fonte em flutter/web. Não é reconhecimento generativo nem substituição do serviço de áudio do navegador. Não garante escuta offline ou suporte de navegadores internos. Regras adicionais não significam suporte a toda frase possível. Captura física de voz, ruído, Bluetooth e sotaques exigem teste no aparelho.

## Validação
`node --test flutter/test/web/recognition_adapter.test.cjs` — 18 aprovados.
`node --check flutter/web/voice/recognition_adapter.js` e cópia de produção — aprovados.
Os testes usam eventos ASR simulados; não representam gravação de voz real.

## Exemplos para o aparelho
1. Me leva pra Praia do Olho d’Água.
2. Onde fica a Igreja do Desterro?
3. Gostaria de ir para Barreirinhas.
4. Não, eu falei Santo Amaro.
5. Localize restaurante em Barreirinhas com cupons depois de amanhã.
Confira o texto reconhecido e o destino. Uma consulta não emite cupom nem comprova disponibilidade.
