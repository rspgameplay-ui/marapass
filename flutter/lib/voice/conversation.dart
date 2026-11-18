import '../domain/municipality.dart';
import '../domain/tourism.dart';
import 'command.dart';

enum ConversationAction { search, confirmRoute, cancel, clarify }

class ConversationTurn {
  const ConversationTurn(
    this.action, {
    this.command,
    this.message,
    this.destination,
  });
  final ConversationAction action;
  final MapCommand? command;
  final String? message;
  final TourismPlace? destination;
}

/// Ephemeral to the open search sheet. Draft transcriptions never mutate context.
class MapConversation {
  MapCommand? previous;
  TourismPlace? pendingRoute;
  List<TourismPlace> candidates = [];
  Set<String> excluded = {};
  MapCommand draft(String text, List<Municipality> cities, {DateTime? now}) {
    final p = parseCommand(text, cities, now: now, requireCouponCity: false);
    if (p.error != null) return p;
    final raw = normalize(text);
    final followUp = RegExp(
      r'\b(quis dizer|na verdade|somente|apenas|so|outra|outro|nao|sim|primeir[oa]|segund[oa]|terceir[oa]|quarta|quarto)\b',
    ).hasMatch(raw);
    final contextualCity =
        previous != null &&
        previous!.coupons &&
        previous!.city == null &&
        p.city != null;
    final contextualName =
        previous != null &&
        previous!.route &&
        candidates.isNotEmpty &&
        !p.route &&
        p.category == null &&
        p.city == null;
    if ((!followUp && !contextualCity && !contextualName) || previous == null) {
      return p;
    }
    final last = previous!;
    final uniqueCity = candidates.map((c) => c.city).toSet();
    Municipality? inferred;
    if (uniqueCity.length == 1) {
      for (final city in cities) {
        if (city.name == uniqueCity.single) inferred = city;
      }
    }
    return MapCommand(
      city: p.city ?? last.city ?? inferred,
      category: p.category ?? last.category,
      day: p.day ?? last.day,
      coupons: p.coupons || last.coupons,
      route: p.route || last.route,
      term: p.term.isEmpty
          ? (raw.contains('outr') && raw.contains('praia')
                ? 'praia'
                : last.term)
          : p.term,
    );
  }

  ConversationTurn accept(
    String text,
    List<Municipality> cities, {
    DateTime? now,
  }) {
    final raw = normalize(text)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (RegExp(r'^(cancelar|cancele|pare|desistir|esqueca|nao obrigado)$')
        .hasMatch(raw)) {
      pendingRoute = null;
      previous = null;
      candidates = [];
      excluded = {};
      return const ConversationTurn(
        ConversationAction.cancel,
        message: 'Busca cancelada. Diga um novo destino quando quiser.',
      );
    }
    if (raw == 'nao') {
      if (pendingRoute != null) excluded.add(pendingRoute!.id);
      pendingRoute = null;
      return const ConversationTurn(
        ConversationAction.clarify,
        message: 'Tudo bem. Diga outro local ou escolha uma opção da lista.',
      );
    }
    if (RegExp(
      r'^(sim|isso|isso mesmo|confirmo|confirmar|pode calcular|pode tracar|vamos la)$',
    ).hasMatch(raw)) {
      final p = pendingRoute;
      if (p == null) {
        return const ConversationTurn(
          ConversationAction.clarify,
          message: 'Ainda não há um destino escolhido. Diga o nome do local.',
        );
      }
      pendingRoute = null;
      return ConversationTurn(ConversationAction.confirmRoute, destination: p);
    }
    final ordinal = RegExp(
      r'^(?:o |a |quero (?:o |a )?)?(primeiro|primeira|segundo|segunda|terceiro|terceira|quarto|quarta|[1-4])(?: opcao)?$',
    ).firstMatch(raw);
    if (ordinal != null) {
      final word = ordinal[1]!;
      final i = {
        'primeiro': 0,
        'primeira': 0,
        'segundo': 1,
        'segunda': 1,
        'terceiro': 2,
        'terceira': 2,
        'quarto': 3,
        'quarta': 3,
        '1': 0,
        '2': 1,
        '3': 2,
        '4': 3,
      }[word]!;
      if (i >= candidates.length) {
        return const ConversationTurn(
          ConversationAction.clarify,
          message: 'Essa opção não está na lista. Escolha um dos resultados exibidos.',
        );
      }
      choose(candidates[i]);
      return ConversationTurn(
        ConversationAction.clarify,
        message: routeQuestion,
      );
    }
    final other = RegExp(r'\b(outra|outro)\b').hasMatch(raw);
    if (other && previous == null) {
      return const ConversationTurn(
        ConversationAction.clarify,
        message: 'Qual local você procura? Diga o nome ou o município.',
      );
    }
    if (other) {
      if (pendingRoute != null) {
        excluded.add(pendingRoute!.id);
      } else if (candidates.length == 1)
        excluded.add(candidates.single.id);
    } else {
      excluded = {};
    }
    pendingRoute = null;
    final p = draft(text, cities, now: now);
    if (p.error != null) {
      return ConversationTurn(ConversationAction.clarify, message: p.error);
    }
    if (p.coupons && p.city == null) {
      if(p.route&&p.term.isEmpty&&p.city==null&&p.category==null)return const ConversationTurn(ConversationAction.clarify,message:'Qual é o destino? Diga o nome do lugar ou município.');
    previous = p;
      return const ConversationTurn(
        ConversationAction.clarify,
        message: 'Em qual município você quer consultar as ofertas?',
      );
    }
    if(p.route&&p.term.isEmpty&&p.city==null&&p.category==null)return const ConversationTurn(ConversationAction.clarify,message:'Qual é o destino? Diga o nome do lugar ou município.');
    previous = p;
    return ConversationTurn(ConversationAction.search, command: p);
  }

  void results(List<TourismPlace> found) {
    candidates = found;
    pendingRoute = null;
  }

  void choose(TourismPlace p) {
    pendingRoute = p;
  }

  String get routeQuestion => pendingRoute == null
      ? 'Qual destes locais você deseja?'
      : 'Encontrei ${pendingRoute!.name}, em ${pendingRoute!.city}. Quer planejar a rota?';
}
