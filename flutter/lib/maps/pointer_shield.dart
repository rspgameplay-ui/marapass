import 'package:flutter/widgets.dart';

import 'pointer_shield_stub.dart'
    if (dart.library.js_interop) 'pointer_shield_web.dart'
    as platform;

/// Faz controles do Flutter desenhados sobre a vista 3D (iframe) receberem
/// toques no navegador. Sem isso, o iframe captura os eventos da área dele e
/// botões como "Encerrar" não respondem. Mesmo princípio do pacote
/// `pointer_interceptor`, sem dependência nova. Fora da web, ou com
/// [enabled] falso, apenas devolve [child].
class PointerShield extends StatelessWidget {
  const PointerShield({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (enabled && platform.shieldSupported)
        const Positioned.fill(child: platform.ShieldLayer()),
      // Chave estável: ligar/desligar a proteção não recria o controle.
      KeyedSubtree(key: const ValueKey('pointer-shield-child'), child: child),
    ],
  );
}
