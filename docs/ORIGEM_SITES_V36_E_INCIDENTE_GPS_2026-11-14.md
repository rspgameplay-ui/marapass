# MaraPass — origem da prévia, inventário e bloqueio GPS

> **Atualização (14/11/2026, noite):** as conclusões abaixo sobre a fonte da v36 estão **superadas**. O código-fonte exato da v36 (commit `91b1e7e`) foi recuperado depois pelo conector Sites e preservado na branch `backup/marapass-versao-publicada`. A correção candidata do GPS foi feita sobre essa fonte, na branch `correcao/gps-v36-2026-11-14` (relatório em `docs/recuperacao-v36/RELATORIO.md` daquela branch). O texto original é mantido abaixo como registro histórico.

Data: 2026-11-14

## Identificadores confirmados no histórico do projeto
- Projeto ChatGPT Sites: `sites-project://appgprj_6ae2a181664881919884e3aa93086765` — nome histórico “MaraPass — Mapa em Flutter”.
- Prévia pública indicada pelo proprietário: https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site/
- Diretório temporário de desenvolvimento identificado no histórico: `existing-map/.sites-checkout/navigation3d/`.
- Arquivos citados nesse diretório: `README.md`, `src/main.tsx`, `src/marapass-style.json`; usados em uma evolução web MapLibre/WebGL, não devem ser confundidos com os fontes do pacote Flutter V1.
- Histórico menciona as versões V17, V19, V20, V34 e V36. A **versão efetivamente servida atualmente no link ainda não foi verificada por hash nem inspecionada**. Registros de V36 salva e de V36 publicada precisam ser conciliados com o artefato real.

## Material local recuperado (não equivale à V36 publicada)
| Artefato | SHA-256 | Natureza |
| --- | --- | --- |
| `MaraPass_Mapa_Flutter_V1.zip` | `7e6c0442eada80fcc508b23b16c4cfa9110923b46cb4bf7e3892b13a66f3d16f` | Base Flutter V1 |
| `MaraPass_Codigo_Recuperado_2026-11-14.zip` | `3b1800ee9c522b1b4f41fff649a68e5230fbcceb4437e893145351163bb6b26c` | Recuperação de arquivos adicionais |
| `MaraPass_Flutter_GPS_Safari_Correcao_2026-11-14.zip` | `889a255c36b4856e4ca5a3ff9cd246c0db41630b72635d4e58606779d3505349` | Patch experimental sobre V1, NÃO publicado na V36 |

Os ZIPs estão na Biblioteca/arquivos da conversa; a presente branch armazena fontes parciais e documentos, não o projeto web completo da V36. Este inventário não declara que os ZIPs estejam disponíveis como artefatos deste repositório.

## Incidente GPS
- No iPhone/Safari, ao tocar em “Iniciar com meu GPS” na prévia, a página falha com “A problem repeatedly occurred”.
- Reproduzido pelo proprietário. A causa técnica **não foi provada**. As hipóteses incluem erro no ciclo de geolocalização web e sobrecarga WebGL/câmera durante acompanhamento, mas não há logs completos da V36.
- Issue operacional: https://github.com/dfelipeamorim/marapass/issues/3

## Restrições e procedimento seguro
1. Não alterar a publicação atual nem substituir a cartografia por uma versão mais antiga.
2. Reabrir o projeto identificado pelo ID no editor Sites original; exportar **fontes atuais e metadados do deploy** (commit, build, configuração), com identificação do artefato servido no endereço.
3. Capturar um snapshot imutável da versão atual antes de aplicar patches; comparar arquivos e checksums.
4. Inspecionar o manipulador do botão, `navigator.geolocation`, a criação do stream, `setCamera`/`jumpTo`/`easeTo`, atualização de camadas e listeners em `src/main.tsx` e módulos reais.
5. Criar branch de correção a partir do snapshot exato, adicionar logging com privacidade (não salvar coordenadas individuais), desligar temporariamente apenas o *follow camera* para isolar o crash.
6. Testar Safari/iOS com GPS negado/aceito, rota curta/longa, alternância 2D/3D, troca de aba, 10 inícios seguidos e retomada; verificar build e logs.
7. Promover apenas após homologação e manter rollback para versão anterior.

## Bloqueios verificados em 2026-11-14
- O URL público não pôde ser lido neste ambiente de ferramentas; não inferir seu conteúdo.
- Não existe, nas ferramentas atualmente expostas, ação direta para abrir/editar o projeto Sites por `sites-project://`.
- Flutter/Dart SDK indisponível no runtime de inspeção; sem compilação/teste nativo/real Safari.
- Não há fonte comprovada da V36 nesta branch; portanto nenhum patch de V1 pode ser declarado como correção em produção.

## Integridade
Preservar: praias e aliases, atrativos, municípios e polos, roteamento, geolocalização, voz, cupons, camadas, estilos, navegação 3D e dados Supabase. Esta recuperação é somente documental e não faz deploy.
