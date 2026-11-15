# MaraPass v36: recuperação e candidato de correção GPS

Data: 14/11/2026. Issue: https://github.com/dfelipeamorim/marapass/issues/3.

**Status: fonte exata recuperada e preservada; candidato compilado e testado localmente. Incidente não encerrado: faltam Safari/iPhone real, medição gráfica e homologação. Nenhuma publicação ou operação de banco foi realizada.**

## 1. Versão efetivamente publicada e recuperação

- Sites: `appgprj_6ae2a181664881919884e3aa93086765`, “MaraPass — Mapa em Flutter”.
- Publicação: https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site/.
- v36: `appgprj_6ae2a181664881919884e3aa93086765~appgver_70adcd9f657c81918c3e35059e4ce62e`.
- Deploy confirmado `succeeded`: `appgdep_6af8244479e08191a5395ccab32215bd`, atualizado em `2026-11-14T09:05:27.337573+00:00`.
- Commit: `91b1e7e99c91d0ed1bcdd394c623327a33b26402`.
- Identificação Flutter do build: `0.7.0+8`; `.last_build_id`: `b9884e27770ab55be956e90d08e01c6a`.
- Consulta final do Sites manteve versão 36, URL e data de atualização originais.

O conector Sites forneceu acesso autenticado ao repositório de origem, que foi clonado sem push para o Sites. A árvore local está em `/workspace/marapass-sites-original`. O HEAD coincide com o SHA da v36. O caminho temporário histórico `existing-map/.sites-checkout/navigation3d/` não estava montado; seu conteúdo foi recuperado no repositório de origem, junto com o Flutter completo.

O histórico consultado expôs 36 versões salvas, com commits e metadados de artefatos. Uma versão salva não foi tratada automaticamente como publicada: o deploy da v36 foi verificado separadamente. A issue e seus cinco comentários foram lidos para distinguir a recuperação histórica parcial desta recuperação.

Estrutura recuperada: `flutter/` (Dart, plataformas, testes, dados, administração e configuração), `navigation3d/` (React/TypeScript/MapLibre/Three.js), `dist/` (build publicado) e `docs/`. A navegação GPS, rotas, voz, busca, cupons e catálogo são controlados pelo Flutter; o 3D recebe quadros por iframe da mesma origem. Não foi usado Flutter V1 como substituto.

O rebuild original do módulo 3D reproduziu **byte a byte** o JS `index-DSFgF5x4.js` e o CSS `index-S-HJ2tGl.css` de `dist/navigation-3d/`. Não se afirma reprodução byte a byte de todo o Dart compilado; o vínculo deste é o commit de origem informado pelo Sites, que também contém o build completo.

## 2. Backup e hashes

Branch criada sem sobrescrever referências:
https://github.com/dfelipeamorim/marapass/tree/backup/marapass-versao-publicada

A branch aponta diretamente ao commit da v36 e preserva os **382 arquivos rastreados / 98.176.570 bytes**, além de seu histórico ancestral, incluindo todas as fontes e `dist/`. O SHA foi conferido novamente via `git ls-remote`. `main` e as branches históricas do GitHub não foram alteradas.

Exportações locais anteriores à edição:

| Arquivo | SHA-256 |
| --- | --- |
| `marapass-v36-source-and-build.tar.gz` | `e7a89c906e7b1e3a9bb13b66afacf618930d9894ee3f97bf0b617981f8add7fc` |
| `marapass-sites-history.bundle` | `fd424a6dd738d459a3c67ee9abb0a90033d840297a08117a9aaef8e05bba2318` |
| `v36-files-sha256.json` | `871941649473f52e6b779f610ce9272d1e278f9c2fef68ad25c23d91d8e986a7` |

Os arquivos estão em `/workspace/marapass-recovery/`. O inventário por arquivo e a proveniência também estão versionados nesta pasta de documentação. A inspeção de padrões usuais de chaves privadas, token GitHub, chave AWS e service role no HEAD não encontrou correspondências. Credenciais temporárias Sites ficaram em memória e não foram gravadas em arquivos/commits.

O artefato de deploy **registrado pelo servidor** tem SHA-256 `ced193dfe388cdbf71946c5f8aeb194b27224465de02e4a5e4fcf4d79b49cacc`, 70.072.320 bytes / 89 arquivos. Ele excede o limite de 32 MiB do downloader disponível; não foi baixado nem confundido com o TAR.GZ exportado. O `dist/` completo foi recuperado pelo Git. O hash remoto permanece metadado do Sites, não uma verificação local desse TAR.

## 3. Diagnóstico: evidências e limites

Observado no código original:

1. A aquisição web inicial usava `watchPosition`, posteriormente cancelado, e a navegação abria outra observação. `authorize()` verificava contexto seguro e política; a permissão efetiva era solicitada pela API de localização.
2. Depois da primeira posição válida, a sessão mudava imediatamente para navegação com `follow=true`. O iframe 3D podia ser criado antes da primeira leitura da observação contínua.
3. A animação do mapa 2D movia a câmera a cada quadro da animação de 800 ms. As notificações do stream GPS não tinham limitação na sessão.
4. O MapLibre usava o pixel ratio do dispositivo e o cache padrão; coexistia com o runtime Flutter/CanvasKit, terreno e uma camada Three.js.
5. A consulta de suporte WebGL criava contexto de teste sem liberar explicitamente nem reutilizar seu resultado.
6. Já existiam proteção `starting`, cancelamento de subscriptions, limitação de recálculo e alguma validação de precisão. Não há evidência de múltiplas sessões simultâneas como causa confirmada.

Esses fatores justificam controlar a inicialização e reduzir trabalho, mas **não comprovam a causa do encerramento do WebKit**. Não há log de processo WebKit, jetsam, console do aparelho ou perfil de memória que identifique a última etapa executada no incidente real. Nem GPS nem WebGL foram declarados culpados exclusivos. Erros de processo podem ocorrer sem exceção JavaScript capturável.

## 4. Alterações do candidato

Branch exclusiva: `correcao/gps-v36-2026-11-14`, derivada do commit exato da v36.

| Arquivo de fonte | Alteração |
| --- | --- |
| `flutter/lib/location/location_service.dart` | Interface opcional para aquisição inicial, mantendo compatibilidade com gateways nativos e testes; fases técnicas. |
| `flutter/lib/location/location_web.dart` | `getCurrentPosition` na aquisição inicial; novas tentativas de posição imprecisa espaçadas em 1 s, sob timeout global existente; `watchPosition` somente no acompanhamento; callbacks tardios e timer descartados após cancelamento. A API de posição pontual não oferece cancelamento nativo, por isso seu callback é ignorado quando encerrado. |
| `flutter/lib/application/navigation_session.dart` | Inicialização em etapas, validação existente preservada, coalescência de posições a no máximo 2 atualizações/s; câmera liberada após duas leituras contínuas válidas com timestamps distintos e intervalo observado de pelo menos 1 s; limpeza em erro, pausa e descarte; perda de stream retorna à prévia; acompanhamento não invalidado por revisão de rota. |
| `flutter/lib/presentation/navigation_screen.dart` | Seguimento 2D/3D condicionado à estabilidade e ausência de sinal ruim; carregamento inicial 3D aguarda estabilidade. Simulação e escolha 2D/3D preservadas. |
| `flutter/lib/maps/road_map.dart` | Movimentos da câmera 2D limitados a um por 100 ms, mantendo animação do marcador. |
| `flutter/lib/core/vector_support_web.dart` | Resultado do probe WebGL reutilizado e contexto de teste liberado pela extensão opcional. |
| `flutter/lib/maps/navigation_3d_web.dart` | Instrumentação de fases e descarte explícito do iframe/listeners/estado. |
| `flutter/lib/location/gps_diagnostics*.dart` | Vocabulário fechado de etapas; somente com `?gpsDiagnostics=1`, buffer local de até 100 eventos em sessionStorage. Registra etapa e horário, sem coordenadas, rotas, nomes ou texto de exceções; sem transporte de rede. |
| `navigation3d/src/main.tsx` | Diagnóstico do primeiro quadro/câmera/render e perda de contexto; tratamento de exceções no flush; pixel ratio máximo 1,5 e cache de tiles limitado; reset de estado GL compartilhado; pausa de câmera ao ocultar a página; limpeza de listeners e referências. Estilo, terreno e camadas mantidos. |
| `flutter/test/gps_startup_test.dart` | Testes de ciclo de sessão, duplicidade, estabilização, limitação, falhas, fechamento, recuperação e rota longa. |

Também foram atualizados os bundles gerados em `flutter/web/navigation-3d/` e `dist/`, com `dist/recovery-build.json` identificando o candidato e sua homologação pendente. O build estava ausente de três arquivos Roboto originais não declarados no pubspec; eles foram recolocados byte a byte no pacote, preservando todos os assets anteriores.

**111 arquivos protegidos foram comparados por SHA-256 e permanecem idênticos**, abrangendo assets Flutter e publicados, administração, dados e domínio, busca/voz, configuração, servidor Supabase, estilo 3D e manifests/lockfiles. `preservation-check.json` lista os caminhos. Nenhum catálogo, alias, coordenada, dado de cupons, camada ou banco foi modificado. A preservação inclui funções e fontes; não substitui a homologação funcional completa.

## 5. Verificações executadas

Ferramentas: Flutter **3.47.8 / Dart 3.13.7**, revisão exata da `.metadata`; dependências recuperadas com `flutter pub get --enforce-lockfile`. O SDK estável 3.50.0 exigia mudança de quatro dependências e foi descartado para esta validação, sem alterar o lockfile.

| Verificação | Resultado |
| --- | --- |
| TypeScript `tsc --noEmit` + Vite, original | Passou; JS/CSS idênticos ao build recuperado. |
| TypeScript + Vite, candidato | Passou; avisos de tamanho do bundle e diretivas de dependência, sem erro. |
| `flutter analyze --no-pub` | 0 erros, 4 warnings, 101 infos; exit 1 por avisos. Base intacta: 0 erros, mesmos 4 warnings, 102 infos. Não foi declarado lint totalmente limpo. |
| Suíte Flutter completa | **119 aprovados, 3 falhas** preexistentes. Inclui os oito testes GPS inicialmente adicionados. |
| Comparação na base intacta dos três arquivos com falhas | **7 aprovados, mesmas 3 falhas**, confirmando divergências anteriores ao patch. |
| Dez ciclos GPS no teste automatizado | Passaram; cliques duplicados não abriram sessões extras, câmera aguardou estabilidade, subscriptions foram canceladas. GPS simulado em VM, não iPhone. |
| JS: ambiente + adaptador de voz | 2 testes aprovados. |
| Catálogo de praias Python | 6 testes aprovados. |
| `flutter build web --release --no-pub --no-web-resources-cdn --dart-define-from-file=config/catalogo.json` | Passou. O dry run opcional de Wasm aponta casts em `flutter_tts` preexistente; o alvo JavaScript release solicitado foi compilado. |
| Integridade de dados e configuração | 111 arquivos protegidos idênticos por SHA-256; sem alteração de banco. |

As três falhas preexistentes são: `terrain_test.dart` espera 4.224 e encontra 4.217; `municipal_review_test.dart` espera 50 e encontra 51; `municipalities_test.dart` não aceita a data já presente `2026-11-09`. Não se editaram esses dados nem testes para mascarar os resultados.

A suíte adicional focada, incluindo recuperação após timeout e revisão de rota, tem seu resultado registrado em `evidencias/gps-focused-tests.log` e na seção de encerramento abaixo.

As primeiras tentativas de execução tiveram bloqueios locais de socket e cache do analisador pelo sandbox; foram reexecutadas com a permissão apropriada do executor. Isso não foi classificado como falha funcional do app. A ferramenta de navegador `cua_repl.js` não está disponível neste ambiente gerenciado. Conforme o fluxo de preview do Sites, não se iniciou servidor alternativo nem se improvisou automação de navegador. Não há Safari/iPhone real disponível. Não houve medida de memória gráfica real, teste visual 2D/3D nem reprodução do crash nesta sessão.

## 6. Homologação e publicação

Candidato local: `dist/recovery-build.json`, identificador `gps-v36-20261114`. O pacote de homologação contém o build completo em TAR.GZ, sem manifest de identidade Sites, para não apontar automaticamente à produção. **URL de homologação: não criada.** A publicação, inclusive em um novo Sites separado, depende da confirmação solicitada pelo usuário. Nenhuma versão Sites nova foi salva ou implantada nesta intervenção.

Passos pendentes:

1. Após confirmação, criar um Site de homologação separado e privado com o mesmo build/configuração permitida, preservando o projeto original. Acesso de parceiros/admin não deve ser exercitado com gravações em produção.
2. Conferir `recovery-build.json` no endereço testado. No iPhone real, testar dez inicializações consecutivas no Safari, com pausa entre sessões, e registrar modelo/iOS/Safari, resultados e consumo de memória. O critério de aceitação ainda não foi satisfeito no aparelho real.
3. Repetir permissão aceita/negada/revogada, GPS desligado/timeout/imprecisão, cancelamento durante aquisição, perda e retorno de sinal, segundo plano/retomada e gestos/recentralização, nas vistas 2D/3D e em rotas curta/longa/trecho náutico.
4. Para separar etapas, usar Web Inspector e os estados registrados; testar posição pontual isolada, watch sem câmera e depois seguimento/renderização. Usar breakpoints ou build de diagnóstico, sem simular coordenadas pessoais em relatórios.
5. Com `?gpsDiagnostics=1`, exportar apenas `sessionStorage.getItem('marapass.gps.diagnostics.v1')` no Web Inspector. O buffer é limitado; colher após cada tentativa. Limpar com `sessionStorage.removeItem('marapass.gps.diagnostics.v1')`. Se o processo reiniciar e o armazenamento não persistir, usar também logs de sistema/jetsam do aparelho. O último estágio indica onde investigar; não prova sozinho a causa.
6. Homologar catálogo, busca tolerante/voz/comandos, praias, municípios, polos, ilhas, camadas, voz de orientação e cupons/parceiros em leitura. Só depois propor promoção à URL original, com nova confirmação de publicação.

## 7. Rollback

A publicação original permanece v36; não é necessário rollback neste momento. Para referência futura, a versão Sites e o deploy exatos estão acima e em `provenance.json`. Um rollback autorizado pode reutilizar a versão Sites v36 existente, sem rebuild e sem alteração de dados de banco.

A recuperação local independente pode ser feita por `git clone --branch backup/marapass-versao-publicada https://github.com/dfelipeamorim/marapass.git` ou por clone do bundle exportado. O TAR.GZ contém a árvore integral e o inventário permite verificar cada arquivo. Não fazer force-push, reset de branches compartilhadas ou deploy automático em resposta a esta documentação.

Os logs versionados tiveram somente códigos de cor ANSI e espaços finais removidos para leitura; os logs locais originais permanecem em `/workspace/marapass-recovery/`.

## 8. Encerramento da execução local

- Análise estática final do novo arquivo de testes: **nenhum problema encontrado** (`evidencias/gps-test-analyze.log`).
- Suíte focada final: **23 testes aprovados**, incluindo os dez novos testes de GPS, recuperação após timeout e manutenção do acompanhamento após revisão de rota. Evidência: `evidencias/gps-focused-tests.log`.
- Pacote de homologação: `marapass-gps-v36-homologacao.tar.gz`, 22.250.286 bytes / 89 arquivos. SHA-256: `fec341d9a07ed207bdd65c0ecb8506b17eced42a9d37b74047c0b65f98f7797e`.
- Integridade do pacote conferida por leitura do TAR: `index.html` e `recovery-build.json` presentes; identidade de deploy Sites ausente. O manifesto dos arquivos exportados está em `artifacts.json`.
- Original continua v36; causa exata ainda não comprovada; homologação real e publicação separada permanecem pendentes.
