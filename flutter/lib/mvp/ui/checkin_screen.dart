import 'package:flutter/material.dart';

import '../theme/widgets.dart';
import 'home_screen.dart';

/// O check-in por QR e por proximidade fica para a próxima versão (precisa de
/// leitura de placa no parceiro e RPC dedicada). A aba existe para manter a
/// navegação oficial e é honesta sobre o que ainda não funciona.
class CheckinScreen extends StatelessWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Check-in')),
    body: MpEmpty(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Check-in chega na próxima versão',
      message: 'Em breve você registra a visita lendo a placa MaraPass do local e acumula carimbos no passaporte. Por enquanto, explore o mapa.',
      actionLabel: 'Abrir o mapa',
      onAction: () => openMap(context),
    ),
  );
}
