import '../domain/tourism.dart';

String _spoken(String text) =>
    normalize(text)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

String? driveDestination(String text) => RegExp(
  r'^(?:oi )?(?:marapes|marape|marapass) (?:por favor )?'
  r'(?:(?:mude|muda|troque|troca|altere) (?:a rota|o destino) (?:para|pra|pro)|'
  r'(?:rota|navegue|vamos|bora|quero ir) (?:para|pra|pro)|'
  r'me (?:leve|leva) (?:para|pra|pro|ate)) (.+)$',
).firstMatch(_spoken(text))?.group(1);

bool confirmsDriveDestination(String text) =>
    RegExp(r'^(?:sim|confirmo|confirmar|pode mudar)$').hasMatch(_spoken(text));

bool cancelsDriveDestination(String text) =>
    RegExp(r'^(?:nao|cancelar|cancele|mantenha a rota)$')
        .hasMatch(_spoken(text));
