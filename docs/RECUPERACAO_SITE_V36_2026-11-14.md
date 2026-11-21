# MaraPass — Recuperação rastreável do site v36 (14/11/2026)

> **Atualização (14/11/2026, noite):** as conclusões abaixo sobre a fonte da v36 estão **superadas**. O código-fonte exato da v36 (commit `91b1e7e`) foi recuperado depois pelo conector Sites e preservado na branch `backup/marapass-versao-publicada`. A correção candidata do GPS foi feita sobre essa fonte, na branch `correcao/gps-v36-2026-11-14` (relatório em `docs/recuperacao-v36/RELATORIO.md` daquela branch). O texto original é mantido abaixo como registro histórico.

## Resultado
O histórico do projeto ChatGPT contém evidência de desenvolvimento e publicação da versão 36 do site `https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site/` em 14/11/2026. **O código-fonte exato da v36 não foi recuperado neste commit.** A correção de GPS feita no Flutter V1 não foi aplicada à v36.

## Caminhos da versão v36 registrados no histórico
- Workspace Sites: `/workspace/scratch/596ccdbb17be/existing-map/.sites-checkout/`.
- Módulo de navegação 3D: `navigation3d/src/main.tsx`.
- Estilo: `navigation3d/src/marapass-style.json`.
- Documentação: `navigation3d/README.md`.
- Features relatadas na v36: câmera 3D inclinada 66°, câmera/recentralização, rota ciano, mapa satélite híbrido, painéis de manobras e POIs.

**Estes são caminhos históricos, não arquivos montados e inspecionados neste ambiente**. O checkout pode ser temporário.

## Pacotes de código efetivamente recuperados
- Biblioteca `/MaraPass/MaraPass_Mapa_Flutter_V1.zip` (161 arquivos ZIP; 39 arquivos Dart).
- Biblioteca `/MaraPass_Codigo_Recuperado_2026-11-14.zip` (174 arquivos ZIP; 44 arquivos Dart; includes historical code, prototypes, some Supabase artifacts).
- `/MaraPass/MaraPass_Mapa_Praias_V5_HOMOLOGACAO_NAO_PUBLICADO.zip`: arquivo listado na Biblioteca, mas a materialização dos bytes foi rejeitada; os testes descritos no relatório de homologação eram simulados, não confirmação da v36.
- `/MaraPass/RELATORIO_HOMOLOGACAO.md`: disponível e lido; relata 45 praias candidatas com acessos ainda não validados (estado 11/11), não necessariamente o conteúdo da v36.
- Flutter GPS patch em pacote `MaraPass_Flutter_GPS_Safari_Correcao_2026-11-14.zip`: altera V1, **não** v36.

## Histórico dos pacotes temporários não recuperados neste ambiente
- 07/11 v17: `/workspace/scratch/MaraPass_Flutter_v17_codigo.zip`, `/workspace/sites/marapass-map/.sites-checkout/docs/entrega-design-ambiente-v17.md`.
- 08/11 v19: `/workspace/scratch/MaraPass-v19-codigo.zip`.
- 08/11 v20: `/workspace/scratch/MaraPass-v20-codigo.zip`.
- 13/11 v34/v35: relatos de publicação e testes, sem fonte integral montada.
- 14/11 v36: relato de publicação e módulo Navigation 3D, sem ZIP integral montado.

## Limitações verificadas
- O site público não pôde ser lido no ambiente (recurso web bloqueado).
- Não existe `/workspace` montado no contêiner atual.
- Branch `main` do GitHub só tem README inicial.
- Branch `recuperacao/codigo-2026-11-14` tem snapshot parcial, mas não `navigation3d`.
- Não houve compilação, teste real no Safari ou publicação da correção da v36.
- Não confundir arquivo de homologação v5, que era não publicado, com v36 do site.

## Recuperação segura para continuar
1. Entrar no **mesmo editor Sites/Work** que gerou o domínio `chatgpt.site` e abrir o projeto e histórico da v36.
2. Exportar o checkout **completo** da revisão publicada, incluindo `navigation3d/`, fontes da interface, catálogo, estilos, recursos, manifesto e scripts. Preservar a revisão corrente como snapshot/ZIP antes de editar.
3. Comparar hash de arquivos, identificar commits/deploys, confirmar que o código exportado corresponde ao que está online.
4. Importar esse snapshot para **branch separada** no GitHub, mantendo `main` e produção inalterados.
5. Instrumentar `Iniciar com meu GPS` na v36: permissão, `getCurrentPosition`, stream/watcher, atualização de câmera, ciclo de renderização e liberação de recursos. Sem registrar coordenadas pessoais.
6. Testar no iPhone/Safari e compilar a stack correta; homologar em staging. Publicar no domínio original somente após comprovação.
7. Preservar praias, atrativos, nomes/aliases, busca, voz, navegação 3D, estilos, Supabase e cupons.

## Controle
Incidente relacionado: https://github.com/dfelipeamorim/marapass/issues/3

**Estado:** inventário auditado; recuperação do código v36 pendente. Nenhum dado cartográfico da publicação foi modificado.
