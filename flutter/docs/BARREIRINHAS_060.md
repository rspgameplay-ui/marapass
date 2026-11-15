# Piloto Barreirinhas — 0.6.0+7

## Pronto nesta entrega

- Tela Flutter dedicada, acessível por ?pilot=barreirinhas e pelo botão Explorar Barreirinhas no mapa.
- 174 registros na base inicial do município, incluindo a referência da sede; 173 locais exploráveis, antes de publicações ou alterações locais. Busca por nome, categorias e salvos. A tela inicial destaca nove referências já existentes: Lagoa Azul, Lagoa Bonita, Caburé, Gran Lençóis Flat Residence, Porto Preguiças Resort, O Bambaê, Restaurante da Marina do Gran Lençóis Flat Residence, Guaratur Adventure e uma referência de artesanato.
- A seleção usa dados anteriores OSM/editoriais e não concede parceria, certificação, desconto, funcionamento ou disponibilidade a nenhuma empresa. Nenhuma nota, foto, coordenada ou avaliação foi extraída do Google.
- Orientações de acesso de Lagoa Azul e Lagoa Bonita ancoradas no ICMBio; Caburé mantém o conteúdo editorial anterior. O piloto não oferece rota de carro particular até esses três atrativos de acesso especial.
- Campo opcional googlePlaceId no modelo e no CMS compartilhado, com validação no servidor, rascunho, prévia, publicação e histórico existentes.
- Componente web de consulta do Google Places UI Kit preparado para busca limitada a três resultados ou ficha por ID já associado. Consulta somente por clique e quando configurada. Preserva os componentes e atribuições oficiais; apenas o ID selecionado é enviado ao rascunho, após confirmação humana.

## O que depende de ativação

Não havia chave Google web nos arquivos de configuração nem nas variáveis de ambiente do Site. Portanto esta versão NÃO faz consultas Google ativas e NÃO contém vínculos reais confirmados com place_id. A tela informa esse estado e oferece um link externo explícito ao Google Maps. Esse link não altera o navegador de rotas do MaraPass e não representa sincronização de dados.

O componente Google integrado é web. Android/iOS mostram o estado de piloto web; não foi criado nem validado um adaptador nativo do Places UI Kit nesta entrega.

## Ativação controlada

1. Na conta Google Cloud do MaraPass, configurar faturamento e habilitar Maps JavaScript API e Places UI Kit, conforme a documentação atual do Google.
2. Criar uma chave de navegador restrita às APIs necessárias e aos referenciadores HTTPS do Site. Não usar chave de servidor ou chave sem restrições. Configurar cotas e alertas. O uso é sujeito à cobrança e às condições do Google.
3. Na preparação do build, fornecer a variável GOOGLE_PLACES_WEB_KEY ao script scripts/prepare_web_output.py. Trata-se de chave pública de navegador, incluída no documento do componente. Não a inserir no código Dart, no banco de conteúdo ou em conversas públicas. A configuração de ambiente do servidor do Site, sozinha, não recompila um build estático já publicado.
4. Compilar, preparar e publicar. Sem essa variável o modo permanece desativado. Não há chave de demonstração, credencial emprestada nem habilitação de faturamento automática.
5. Na central → Mapa e conteúdo → informações práticas, escolher um registro de Barreirinhas e usar Conferir correspondência no Google. Conferir visualmente nome e localização; selecionar o local e enviar o ID ao rascunho. Salvar, conferir prévia e publicar. O ID pode ser informado manualmente se obtido por serviço oficial e conferido.
6. Conferir em celular a ficha correspondente, os créditos obrigatórios, limites de consultas e comportamento de erro. A consulta Google real ainda precisa desse teste após ativação; a compilação não o substitui.

## Armazenamento, publicação e isolamento

- googlePlaceId aceita somente identificador opaco com 8 a 255 caracteres ASCII alfanuméricos, hífen ou sublinhado. Não aceita URL, HTML ou objeto. O modelo descarta identificadores inválidos recebidos; o backend rejeita gravações inválidas.
- A alteração foi aplicada à função existente private.map_command por migração map_editorial_google_place_id (versão 20261102223629). Preserva sessão viva, MFA, autorização territorial, permissões, revisão, idempotência e histórico. Não cria acesso novo a tabelas privadas nem usa user_metadata para autorizar.
- Conteúdo Google permanece no componente oficial. O ID é metadado de associação; os dados turísticos e comerciais próprios continuam independentes. O cadastro local ou OSM de uma empresa não comprova parceria MaraPass.
- O iframe tem sandbox sem allow-same-origin. O documento inicial contém o código e a configuração necessários, evitando dependência de subrecursos autenticados do Site dentro do contexto opaco. O SDK Google não recebe acesso ao DOM ou armazenamento do painel pai. A mensagem de associação exige origem opaca, janela exata, diálogo aberto, registro atual e ID válido. Não salva nem publica automaticamente.
- O cabeçalho restritivo de geolocalização do /admin permanece intacto. A consulta do Google não solicita GPS.

## Fontes

- ICMBio: https://www.gov.br/icmbio/pt-br/assuntos/biodiversidade/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/paginas-site-parna-dos-lencois-maranhenses-ma/barreirinhas
- https://developers.google.com/maps/documentation/javascript/places-ui-kit/get-started
- https://developers.google.com/maps/documentation/javascript/places-ui-kit/place-search
- https://developers.google.com/maps/documentation/javascript/places-ui-kit/place-details
- https://cloud.google.com/maps-platform/terms/maps-service-terms (seção 15, exceção específica do UI Kit para mapas de terceiros)

## Validação do cadastro compartilhado

O teste transacional existente passou com publicação do ID e rejeição de ID inválido, além das verificações de conflito, prévia, histórico, restauração, território, revogação e MFA. Todo conteúdo de teste foi revertido. A função mantém SECURITY DEFINER em esquema privado, search_path vazio e os controles anteriores; a alteração não amplia os privilégios concedidos. Não foram publicados parceiros ou ofertas de demonstração.

O diagnóstico de segurança do Supabase já apresentava alertas anteriores sobre políticas para usuários anônimos e proteção de senhas vazadas. Eles não são corrigidos nem agravados por esta associação; exigem revisão própria do projeto de autenticação. Referências de remediação: https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins e https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

A ativação Google real precisa confirmar também o comportamento dos componentes em iframe isolado e as restrições de referenciador da chave; esses cenários não podem ser certificados sem uma chave habilitada.

## Conferências desta entrega

- 38 testes Flutter aprovados, incluindo o piloto em 320 × 740 com texto ampliado em 1,6.
- JavaScript do componente Google e do CMS passou na conferência de sintaxe.
- Fluxo SQL de rascunho, prévia, publicação, histórico, restauração, território e MFA aprovado, com ID Google aceito e valores inválidos recusados; testes revertidos.
- Navegador remoto: filtro Natureza retorna três referências iniciais; Lagoa Bonita apresenta orientação de acesso; iframe isolado informa ausência de chave e oferece consulta externa explícita. Nenhum SDK Google pago foi carregado nesta conferência.
- A consulta real ao Google, a seleção de IDs reais e a associação completa com dados reais do Google permanecem pendentes da configuração e do teste com chave restrita.

Build web release final gerado sem reutilizar artefatos intermediários; a busca foi conferida no topo da tela publicada em prévia. Registro visual: barreirinhas-060.jpg. A imagem mostra referências locais, não dados retornados pelo Google.
