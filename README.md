# MaraPass

Protótipo navegável do **MaraPass**, o passaporte turístico digital do Maranhão.

Feito para ser simples de usar, inclusive por pessoas mais velhas: letras grandes, botões largos e poucas etapas.

## O que dá para fazer

- Cadastro rápido (só o nome) ou entrar sem cadastro
- Tela inicial com saudação por horário, atalhos rápidos, cartão do passaporte com barra de progresso animada e carrossel de passeios em destaque
- Favoritar destinos (coração), filtrar por favoritos, compartilhar e ver numa faixa de 12 meses a melhor época de cada destino, com aviso se agora é boa época
- Ver destinos: Lençóis Maranhenses, Chapada das Mesas, São Luís, Munim, Floresta dos Guarás e Cultura Maranhense
- Ver passeios, restaurantes e pousada de cada destino
- Reservar passeio em etapas: dia, horário (manhã ou tarde), número de pessoas (com ícones) e cupom, com resumo do preço e barra fixa de confirmação
- Pagamento simulado por Pix (QR Code com contagem de expiração), cartão (prévia ao vivo, bandeira, validação por campo e parcelas) ou no local, com recibo animado no fim
- Cupons em formato de ingresso, com carteira de resumo, abas Disponíveis/Usados, aviso de vencimento, ordenação por validade e código que se revela ao toque (com botão de copiar)
- **Mapa real** (Leaflet): imagem de satélite das dunas ou mapa de ruas, pinos por categoria nas coordenadas reais, lugares próximos agrupados em Barreirinhas, rota até o lugar, cartão com "Ver detalhes" e "Como chegar" no Google Maps. Precisa de internet para carregar o mapa.
- Passaporte com nível (Viajante, Explorador, Aventureiro) e barra animada, conquistas, mapa de destinos visitados, reservas e carimbos
- Registrar visita (check-in com QR Code)
- Abertura animada, máscara de celular no cadastro, avisos com contagem de novos, perfil com estatísticas, letra grande e ajuda com busca
- Passeio com lista "o que levar" (marcável), barra de reserva fixa e botão de ligar para restaurantes e pousada
- Check-in com QR Code que se renova a cada 30 segundos e confete ao registrar a visita

> Protótipo de demonstração: cadastro, pagamentos, reservas e check-in são simulados e ficam salvos só no navegador.

## Como abrir

Abra o arquivo `index.html` no navegador, ou acesse a versão publicada no GitHub Pages.

## Tecnologia

Um único arquivo HTML com CSS e JavaScript puros. A única biblioteca externa é o Leaflet (mapa), com imagens da Esri e mapas da CARTO/OpenStreetMap. As imagens estão embutidas no próprio arquivo.
