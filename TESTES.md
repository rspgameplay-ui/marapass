# Testes que só você pode fazer

**App:** https://marapass-teste.pages.dev (no Safari do iPhone)
**Painel do administrador:** https://marapass-teste.pages.dev/admin/ (no computador)

Responda com o número e **OK** ou **FALHOU + o que aconteceu**. Um print ajuda quando algo falhar.
Antes: no iPhone, **Ajustes › Privacidade › Serviços de Localização › Safari** em "Ao usar o app".

---

## O que eu já testei (não precisa repetir)
- **No navegador:** abertura, apresentação, Início, troca de nome, roteiro do dia (com os novos de Atins e Carolina), roteiro traçado no mapa, navegação nova com simulação, passo a passo e encerrar, card de rota, leitor de QR (visor, lanterna, trocar câmera, digitar código), aviso de GPS sem permissão, aba Cupons com a carteira e os vouchers.
- **No servidor, com uma conta de teste:**
  - cadastro de parceiro e aprovação pelo admin;
  - turista sem permissão de se aprovar ou de ler as placas;
  - ativar cupom;
  - check-in com GPS longe (recusado), perto (aceito) e com QR falso (recusado);
  - reserva de passeio e de hospedagem, sem duplicar o pedido;
  - atendimento;
  - painel sem MFA (recusado);
  - exclusão de conta, que apagou tudo.

## Defeitos que encontrei e já corrigi
1. **App sem o Supabase:** a versão publicada hoje estava rodando sem o Supabase (chave antiga na configuração da compilação). Corrigido e publicado.
2. **Hospedagem:** o pedido de reserva de hospedagem era recusado pelo banco. Corrigido.
3. **Roteiro com várias paradas:** cada parada aparecia como "Chegue ao destino". Agora aparece "Chegue à parada 1, 2…".
4. **Código de login:** a tela de login dizia "código de 6 números", mas o código tem 8. Corrigido.
5. **Simular leitura:** o botão aparecia mesmo com a pessoa logada, quando ele nunca funciona. Agora some.

---

## 1. Login e conta (iPhone)
1. Perfil › **Entrar com e-mail** com o seu e-mail real: o código chega na caixa de entrada (veja o spam) e o login funciona.
2. Depois de entrar, feche o Safari e abra de novo: você continua logado.
3. Perfil › **Política de privacidade** e **Termos de uso** abrem no iPhone.

## 2. GPS e navegação de verdade (iPhone, na rua)
4. Mapa › **Traçar rota** até um lugar perto de você: o Safari pede a localização e a rota sai da sua posição real.
5. **Iniciar navegação** e andar ou dirigir alguns minutos: o ponto azul segue você e a manobra muda.
6. Ligue o **alto-falante**: as instruções são faladas em português.
7. Saia da rota de propósito: o app recalcula.

## 3. Câmera e QR (iPhone + placa impressa)
8. Imprima a placa da Lagoa Azul que eu te mandei (ou abra no computador e aponte o celular para a tela).
9. Check-in › **Abrir leitor**: o Safari pede a câmera e a imagem aparece no visor.
10. Aponte para o QR: aparece o carimbo com "+50 pontos" (a placa tem o token, então vale mesmo longe da lagoa).
11. Ler a mesma placa de novo no mesmo dia: avisa que a visita já foi registrada.
12. **Lanterna** e **Trocar câmera** funcionam no seu iPhone (no Safari a lanterna pode não existir; anote).
13. **Busca por voz** no mapa: o microfone entende "lagoas".

## 4. Parceiro (iPhone + painel)
14. Perfil › **Área do parceiro** › preencher e **Enviar cadastro**: aparece "Recebemos o cadastro".
15. No **painel do administrador** (abaixo), aprove o cadastro e volte ao app: a Área do parceiro abre o painel.
16. Crie uma oferta no app; no painel, **Ativar**; no app, ela aparece em Cupons para os turistas.
17. Painel › **QR do balcão** da oferta: leia com outro celular (ou com o leitor do app) e aparece "Oferta encontrada".
18. Ative o cupom em uma conta de turista e valide o código na conta de parceiro: o primeiro uso é aceito e o segundo é recusado.

## 5. Painel do administrador (computador)
19. Abra **https://marapass-teste.pages.dev/admin/** e entre com a conta de administrador (e-mail, senha e o segundo fator/MFA).
    - Hoje existe **1 administrador**, e não é a sua conta. Para você ser administrador, me avise depois de criar o login no app (item 1) que eu te dou acesso. No primeiro acesso, use **Esqueci minha senha** para criar a senha e cadastre o MFA no autenticador.
20. Aba **App MaraPass**: mostra os números (cadastros, ofertas, check-ins, cupons e usuários).
21. **Cadastros de parceiro**: aprovar e recusar funcionam.
22. **Ofertas**: ativar, pausar e recusar funcionam.
23. **Placas e QR**: **Placa com QR** mostra o QR e **Baixar PNG** salva a imagem; mudar o **raio do GPS** e salvar.
24. **Check-ins**: aparecem os seus check-ins do item 10, como "QR da placa".

## 6. Exclusão (deixe para o fim, com uma conta descartável)
25. Perfil › Conta › **Excluir minha conta**: a conta some e o login antigo não traz mais nada.
