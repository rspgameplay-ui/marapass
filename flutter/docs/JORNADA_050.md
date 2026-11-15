# Jornada turística personalizada — MaraPass 0.5.0+6

## Entrega

O planejador e a navegação Flutter passam a apresentar “Descobertas no caminho”. O turista define categorias de interesse, proximidade lateral da rota (500 m, 2 km ou 5 km) e janela à frente durante a navegação (5 km, 20 km ou 50 km). As preferências e os lugares salvos ficam neste navegador/aparelho, sem sincronização entre contas ou dispositivos nesta versão.

A prévia considera todo o percurso. Durante navegação ou simulação, a lista considera o progresso, ignora pontos ultrapassados há mais de 100 m e limita o trecho à janela escolhida. A simulação permanece identificada como fictícia e não solicita GPS, gera check-in, emite cupom nem registra deslocamento real.

## Como o turista usa

1. Escolher um destino e calcular a rota.
2. Abrir “Descobertas no caminho” ou usar o ícone de personalização no cabeçalho.
3. Escolher interesses e proximidade; aplicar. A seleção persiste localmente.
4. Consultar “Para você”, “Cupons” ou “Salvos”. Os cartões explicam a seleção: interesse escolhido, lugar salvo ou oferta publicada.
5. Abrir o lugar para conferir descrição, endereço e horários quando cadastrados, fonte, condição de referência geográfica e eventual oferta.
6. Salvar para visitar ou destacar o ponto no mapa atual. Nenhuma dessas ações altera a rota automaticamente. O controle de recentralizar permite voltar a acompanhar a posição.

Os marcadores representam até 24 sugestões, combinando os primeiros resultados e municípios presentes ao longo do percurso. A lista mostra até 80 resultados e informa quando existem outros. Um ponto escolhido na lista recebe destaque mesmo se estiver fora dos 24 iniciais.

## Seleção geográfica e desempenho

Os candidatos vêm do catálogo exibido no mapa (IBGE/OSM, publicações e conteúdo local visível) e dos estabelecimentos públicos e ativos consultados no retângulo que cobre a rota com margem de 5 km. A filtragem final projeta cada ponto sobre a geometria rodoviária, descartando os que estão fora do corredor escolhido. Destinos municipais de referência não são tratados como atrativos. Projeções são reutilizadas entre leituras GPS e recalculadas se o ponto ou a rota mudam.

As distâncias laterais são em linha reta, explicitamente identificadas. Não representam distância rodoviária, minutos de desvio, acessibilidade, entrada autorizada ou garantia de visitação. A distância à frente acompanha a geometria da rota. A lista pode omitir um local que volte a ser visitado em uma rota que passe repetidamente pelas mesmas coordenadas, pois a projeção usa a ocorrência mais próxima na geometria.

## Parceiros e ofertas reais

O selo comercial exige dados do cadastro de estabelecimentos públicos e ativos. Um POI do OSM ou empresa inserida no CMS não recebe parceria automaticamente.

A consulta existente de ofertas mantém filtro is_published=true e vínculo establishment_id. A exibição exige ID e título, início já alcançado, término ainda não alcançado quando informado, parceiro e confirmação recente (menos de 90 segundos). Datas de vigência inválidas são descartadas. A jornada atualiza essa consulta em cerca de 30 segundos enquanto está aberta e conectada. Cache offline não confirma descontos. Falha na consulta remove a confirmação e aparece no painel; retirada/publicação nova substitui os dados anteriores. Respostas de rotas antigas não substituem a seleção atual. Consultas limitadas a 500 estabelecimentos ou 1.000 ofertas por lote são sinalizadas como parciais.

A oferta apresentada é vinculada pelo ID ao registro consultado; não se cria um cupom local. A emissão/reserva/resgate de coupon_instances ainda não está conectada a essa jornada. O texto ao turista informa que visualizar não emite nem reserva benefício e orienta conferir elegibilidade, estoque e condições.

## Personalização pela equipe

A central já existente “Mapa e conteúdo” permite editar descrição, categoria, acesso, endereço, horários, contatos, fontes e palavras-chave. A equipe salva rascunho, confere prévia e publica. A jornada usa o catálogo público atualizado pelo mapa; rascunhos do CMS não entram na seleção. Os papéis e o histórico existentes continuam aplicados. Parcerias e ofertas permanecem no cadastro comercial, separado da publicação editorial.

Nesta entrega não foram criados parceiros, ofertas ou transações no servidor. Em 2 de novembro de 2026, uma consulta com a chave pública configurada retornou zero estabelecimentos, zero ofertas e zero publicações visíveis ao papel público. Isso não é uma contagem dos cadastros privados. Para aceitação comercial, é necessário publicar um parceiro e uma oferta reais pelos fluxos administrativos correspondentes.

## Privacidade e limites

A personalização usa apenas interesses explicitamente escolhidos, proximidade, progresso da rota e lugares salvos. Não infere perfil demográfico ou sensível, não grava histórico de localização e não envia preferências a outro serviço. A consulta de parceiros usa a área da rota no backend MaraPass já configurado. Não há mudança de Auth, RLS, permissões do Site ou esquema do banco.

Não foram acrescentados alertas automáticos sobrepostos às manobras ou falas publicitárias. A consulta de detalhes é iniciada pelo turista. A validação em viagem com GPS físico segue pendente. A entrega não adiciona trânsito ao vivo, navegação em segundo plano, cálculo de desvio para paradas, nem garante funcionamento/horários dos estabelecimentos.

## Validação da entrega

- Suíte Flutter de 36 testes aprovada. Após os últimos ajustes nos marcadores, os 8 testes relacionados à jornada, detalhes e tela de navegação também passaram. A navegação compacta foi verificada em 320 × 740 com escala de texto 1,6; o detalhe da oferta em 320 × 740.
- Build web release aprovado (Flutter 3.47.8 / Dart 3.13.7).
- Chrome remoto: rota São Luís–Barreirinhas de 255 km, preferências aplicadas, seleção reduzida de 715 para 37 pontos com natureza/cultura, Museu do Reggae salvo e priorizado, estado vazio de cupons confirmado. Registro: descobertas-050.jpg. A imagem mostra prévia, sem GPS físico iniciado.
- Leituras da API pública configurada responderam HTTP 200 com zero registros visíveis para establishments, offers e map_publications. Nenhuma linha foi gravada no servidor.
- As ofertas de teste existem somente nos testes automatizados; não são incluídas nos dados publicados.
