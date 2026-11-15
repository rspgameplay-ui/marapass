import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const shieldSupported = true;

/// Elemento HTML transparente posicionado acima do iframe. Os eventos que ele
/// recebe sobem até a raiz do Flutter, que então os entrega ao widget.
class ShieldLayer extends StatelessWidget {
  const ShieldLayer({super.key});
  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'div',
    isVisible: false,
    onElementCreated: (element) {
      (element as web.HTMLElement).style
        ..width = '100%'
        ..height = '100%';
    },
  );
}
