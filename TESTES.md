# Roteiro de testes do MaraPass

Link: **https://marapass-teste.pages.dev** (abra no Safari do iPhone).
Para responder, mande o número e **OK** ou **FALHOU + o que aconteceu** (ex.: `7 FALHOU: o mapa ficou branco`).
Um print ajuda muito quando algo falhar.

Antes de começar: no iPhone, em **Ajustes › Privacidade › Serviços de Localização › Safari**, deixe "Ao usar o app".

---

## A. Primeiro acesso (sem entrar na conta)
1. A tela de abertura mostra a logo original e "Descubra · Viva · Valorize".
2. A apresentação passa com **Começar** ou **Pular apresentação**.
3. Início: logo, busca, os 4 atalhos (Mapa, Cupons, Check-in, Reservas), cartão do Passaporte e **Roteiro do dia**.
4. As letras estão grandes e legíveis; nada fica cortado ou sobreposto.
5. A barra de baixo tem Início, Mapa, Cupons e Passaporte, e cada aba abre.

## B. Mapa
6. O mapa abre com os pontos agrupados em círculos com número.
7. Tocar num círculo aproxima; tocar num ponto abre o card **com foto**.
8. As pílulas de categoria no topo deslizam e somem suavemente nas bordas.
9. O botão **3D** inclina o mapa e fica azul quando ativo; a bússola volta ao norte.
10. **Buscar no mapa** encontra "Lagoa Azul" e "Casa de Juja".
11. O microfone da busca pede permissão e entende "lagoas" falado.
12. O botão de camadas mostra ilhas e travessias; tocar numa ilha abre "Sobre a ilha".
13. O card de um parceiro de demonstração mostra "Localização aproximada"; o da Casa de Juja não mostra.

## C. Rota e navegação
14. **Traçar rota** pede a sua localização; se negar, abre "De onde você sai?".
15. Escolher uma cidade como partida traça a rota com tempo e distância.
16. O card da rota tem só um botão principal (**Iniciar navegação**), o **3D** ao lado, o lápis para alterar a partida e o **X** para limpar.
17. **Iniciar navegação** abre a tela nova (mapa claro, painel embaixo), não a tela escura antiga.
18. **Simular percurso sem GPS**: o ponto azul anda, a manobra aparece no cartão azul do topo e o tempo diminui.
19. O alto-falante liga a voz das instruções.
20. A lista de passos (ícone de lista) mostra o passo a passo.
21. Ao chegar, aparece "Você chegou!" com **Registrar visita no Passaporte**.
22. Na rua de verdade, **Iniciar navegação** com GPS segue você (teste curto, a pé ou de carro).

## D. Roteiro do dia
23. Início › **Roteiro do dia** mostra Barreirinhas, São Luís, Atins e Carolina.
24. Cada parada tem horário, motivo, plano B e tempo de deslocamento.
25. **Traçar roteiro no mapa** mostra as paradas numeradas e a rota completa.
26. **Iniciar navegação** do roteiro abre a navegação nova.

## E. Conta
27. Perfil › entrar com o seu e-mail: o código chega e o login funciona.
28. Perfil › **Política de privacidade** e **Termos de uso** abrem as páginas.
29. Trocar o nome no Perfil e ver o nome novo no Início.
30. **Letra grande** aumenta o texto em todo o app.

## F. Cupons e carteira (logado)
31. A aba Cupons mostra o cartão **Benefícios MaraPass** (economia, ativos e pontos).
32. Os cupons aparecem como ingresso com o status **Disponível**.
33. Ativar um cupom: revisar, aceitar e ver o QR que se renova a cada 30 segundos.
34. Na lista, o cupom ativado mostra **Ativado**, o código parcial e o botão **Resgatar**.

## G. Check-in e Passaporte (logado)
35. Check-in › **Abrir leitor**: o leitor em tela cheia pede a câmera e mostra o visor amarelo animado.
36. A **lanterna** liga (no iPhone pelo Safari pode não ter, então anote).
37. **Trocar câmera** alterna entre a frontal e a traseira.
38. Ler o QR de uma placa impressa (arquivo `placas/index.html`, que eu te mando): aparece o carimbo animado com "+50 pontos".
39. **Digitar código manualmente** com o código de uma placa: com o GPS longe do local, deve **recusar** e explicar a distância.
40. **Estou no local** longe de qualquer ponto: deve mostrar "Você ainda não está no local".
41. Passaporte › **Extrato**: as visitas aparecem com hora, polo, pontos e saldo.
42. Os carimbos dos polos visitados ficam coloridos.

## H. Hospedagem e reservas (logado)
43. Abrir "Pousada Vila Lençóis": aparecem nota, preço por noite, café incluído, cancelamento grátis e comodidades.
44. **Ver disponibilidade**: trocar as datas e os hóspedes; o total muda.
45. **Solicitar**: aparece em Reservas como pedido enviado.
46. Reservar um passeio (Passeio às Lagoas) e vê-lo em Minhas reservas.

## I. Parceiro (logado)
47. Perfil › **Área do parceiro** abre o formulário **Seja parceiro MaraPass**.
48. Enviar o cadastro mostra "Recebemos o cadastro…". **Me avise aqui que eu aprovo.**
49. Depois de aprovado, a Área do parceiro abre o painel.
50. Criar uma oferta, que fica "Em análise". Me avise para eu ativar.
51. A oferta ativa mostra o **QR da oferta**; ler esse QR em outro celular abre "Oferta encontrada".
52. Conta do parceiro › **Placas MaraPass (QR)** mostra a placa e baixa o PNG.
53. Validar o código de um cupom ativado por outra conta: o primeiro uso é aceito e o segundo é recusado.

## J. Exclusão de conta (deixe para o fim)
54. Perfil › Conta › **Excluir minha conta** (com uma conta de teste, **não** a de parceiro): a conta some e não dá mais para entrar com os dados antigos.
55. Com a conta de parceiro, a exclusão é recusada com o aviso de falar com o suporte.

---

**Limites conhecidos desta versão:** pagamento dentro do app, notificações e as telas de praia e ferramentas avançadas (ainda no visual antigo) ficam para depois. Os parceiros, preços e tarifas são de demonstração.
