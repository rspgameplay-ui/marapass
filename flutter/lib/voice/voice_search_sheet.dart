import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../application/map_state.dart';
import '../domain/tourism.dart';
import '../presentation/navigation_screen.dart';
import '../location/location_service.dart';
import 'command.dart';
import 'conversation.dart';
import 'place_resolver.dart';
import 'speech_engine.dart';
import 'offer_calendar.dart';

/// One engine per app session; the OS/browser performs speech recognition.

class VoiceSearchSheet extends ConsumerStatefulWidget {
  const VoiceSearchSheet({super.key, required this.onFocus});
  final ValueChanged<TourismPlace> onFocus;
  @override
  ConsumerState<VoiceSearchSheet> createState() => _VoiceSearchState();
}

class _VoiceSearchState extends ConsumerState<VoiceSearchSheet>
    with WidgetsBindingObserver {
  final text = TextEditingController();
  final calendar = OfferCalendar();
  final conversation = MapConversation();
  final nearbyLocation = LocationService();
  GeoPoint? nearOrigin;
  String? conversationMessage;
  Set<String> approximateIds = {};
  bool handledUtterance = false;
  bool listening = false,
      initializing = false,
      busy = false,
      closed = false,
      ran = false;
  String? error;
  MapCommand? command;
  List<TourismPlace> found = [];
  Map<String, CalendarOffer> offers = {};
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    closed = true;
    nearbyLocation.cancelPending();
    mapSpeechEngine.onError = null;
    mapSpeechEngine.onStatus = null;
    ++generation;
    mapSpeechEngine.speech.cancel();
    calendar.dispose();
    text.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      mapSpeechEngine.speech.cancel();
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> listen() async {
    if (initializing || busy) return;
    if (listening) {
      await mapSpeechEngine.speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    setState(() {
      initializing = true;
      error = null;
      handledUtterance = false;
      text.clear();
      command = null;
      found = [];
      conversationMessage = null;
    });
    try {
      mapSpeechEngine.onError = (message) {
        if (mounted)
          setState(() {
            listening = false;
            error =
                message.contains('permission') ||
                    message.contains('not_allowed') ||
                    message.contains('not-allowed')
                ? 'Microfone não autorizado. Permita o acesso ou digite o comando.'
                : 'Não consegui ouvir o comando. Tente novamente ou digite.';
          });
      };
      mapSpeechEngine.onStatus = (status) {
        if (mounted && status != 'listening')
          setState(() {
            listening = false;
            if (text.text.trim().isEmpty &&
                (status == 'done' || status == 'notListening')) {
              error = 'Não ouvi o destino. Toque no microfone para tentar novamente ou digite sua busca.';
            }
          });
      };
      final ready = await mapSpeechEngine.initialize();
      if (!mounted) return;
      if (!ready) {
        setState(
          () => error = 'Voz indisponível ou não autorizada neste navegador. Abra no Safari/Chrome compatível ou digite o comando.',
        );
        return;
      }
      final locales = await mapSpeechEngine.speech.locales();
      final brazil = locales.where(
        (l) => l.localeId.replaceAll('_', '-').toLowerCase() == 'pt-br',
      );
      final locale = brazil.isEmpty ? 'pt-BR' : brazil.first.localeId;
      if (!mounted) return;
      setState(() => listening = true);
      await mapSpeechEngine.speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (r) {
          if (!mounted || busy) return;
          text.value = TextEditingValue(
            text: r.recognizedWords,
            selection: TextSelection.collapsed(
              offset: r.recognizedWords.length,
            ),
          );
          interpret();
          if (r.finalResult) {
            setState(() => listening = false);
            if (!handledUtterance && r.recognizedWords.trim().isNotEmpty) {
              handledUtterance = true;
              run();
            }
          }
        },
      );
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Não foi possível usar o microfone. Você pode digitar o mesmo comando.',
        );
    } finally {
      if (mounted) setState(() => initializing = false);
    }
  }

  void interpret() {
    setState(() {
      command = conversation.draft(
        text.text,
        ref.read(repositoryProvider).municipalities,
      );
      error = command!.error;
      ran = false;
      found = [];
      offers = {};
    });
  }

  Future<void> run() async {
    if (busy || listening || text.text.trim().isEmpty) return;
    if (normalize(text.text).trim() == 'mais') {
      setState(() {
        error = 'Ouvi apenas “mais”. Tente novamente e diga o nome do destino ou digite-o.';
      });
      return;
    }
    final turn = conversation.accept(
      text.text,
      ref.read(repositoryProvider).municipalities,
    );
    if (turn.action == ConversationAction.confirmRoute) {
      await openRoute(turn.destination!);
      return;
    }
    if (turn.action != ConversationAction.search) {
      setState(() {
        conversationMessage = turn.message;
        error = null;
        ran = false;
      });
      return;
    }
    final parsed = turn.command!;
    if (parsed.error != null) {
      setState(() => error = parsed.error);
      return;
    }
    FocusScope.of(context).unfocus();
    final revision = ++generation;
    setState(() {
      busy = true;
      error = null;
      command = parsed;
      conversationMessage = null;
      approximateIds = {};
      nearOrigin = null;
      ran = false;
    });
    try {
      List<TourismPlace> next;
      final mapped = <String, CalendarOffer>{};
      final nearbyBeach =
          RegExp(r'\bpraias?\b').hasMatch(normalize(text.text)) &&
          RegExp(r'\b(perto|proxim[oa]s?|ao redor)\b')
              .hasMatch(normalize(text.text));
      if (nearbyBeach) {
        final pos = await nearbyLocation.acquire();
        final origin = GeoPoint(pos.latitude, pos.longitude);
        final nearby =
            ref.read(mapStateProvider).places.where((p) => p.isBeach).toList()
              ..sort(
                (a, b) => origin
                    .distanceKm(a.point)
                    .compareTo(origin.distanceKm(b.point)),
              );
        next = nearby.take(20).toList();
        nearOrigin = origin;
      } else if (parsed.coupons) {
        final local = DateTime.now().toUtc().subtract(const Duration(hours: 3));
        final rows = await calendar.search(
          parsed.day ?? DateTime(local.year, local.month, local.day),
          parsed.city!.name,
          category: parsed.category,
          term: parsed.term,
        );
        next = [];
        for (final row in rows) {
          if (parsed.category != null && row.place.category != parsed.category)
            continue;
          if (parsed.term.isNotEmpty &&
              !normalize('${row.place.name} ${row.title}')
                  .contains(parsed.term))
            continue;
          if (mapped.containsKey(row.place.id)) continue;
          next.add(row.place);
          mapped[row.place.id] = row;
        }
      } else {
        final matches = resolvePlaces(
          parsed,
          ref.read(mapStateProvider).places,
          excluded: conversation.excluded,
        );
        approximateIds = matches
            .where((m) => m.approximate)
            .map((m) => m.place.id)
            .toSet();
        next = matches.map((m) => m.place).toList();
      }
      if (!mounted || revision != generation) return;
      setState(() {
        found = next;
        offers = mapped;
        ran = true;
        conversation.results(next);
        if (parsed.route && next.length == 1) {
          conversation.choose(next.single);
          conversationMessage = conversation.routeQuestion;
        } else if (next.length > 1) {
          conversationMessage =
              'Encontrei ${next.length} locais. Confira o nome e o município antes de escolher.';
        } else if (next.isEmpty) {
          conversationMessage = 'Não encontrei um local seguro para associar a esse pedido. Tente outro nome ou informe o município.';
        }
      });
    } on LocationFailure catch (e) {
      if (mounted && revision == generation) setState(() => error = e.message);
    } on FormatException catch (e) {
      if (mounted && revision == generation) setState(() => error = e.message);
    } catch (_) {
      if (mounted && revision == generation)
        setState(
          () => error = 'Não foi possível concluir a consulta. Confira a conexão e tente novamente.',
        );
    } finally {
      if (mounted && revision == generation) setState(() => busy = false);
    }
  }

  void chooseDestination(TourismPlace p) {
    setState(() {
      conversation.choose(p);
      conversationMessage = conversation.routeQuestion;
    });
  }

  Future<void> openRoute(TourismPlace p) async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NavigationScreen(destination: p, autoPlan: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MaraPass · assistente de viagem',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar busca por voz',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Olá! Para onde vamos? Diga um destino ou o que procura. Se houver mais de uma opção, ajudo você a escolher.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              enabled: !busy,
              maxLines: 3,
              minLines: 2,
              onChanged: (_) => interpret(),
              decoration: const InputDecoration(
                labelText: 'O que entendi',
                hintText: 'Ex.: Vamos para os Lençóis Maranhenses',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: listening ? 'Parar microfone' : 'Falar comando',
                  onPressed: initializing || busy ? null : listen,
                  icon: Icon(
                    listening ? Icons.stop_circle_outlined : Icons.mic_none,
                  ),
                ),
                Expanded(
                  child: Text(
                    initializing
                        ? 'Preparando microfone…'
                        : listening
                        ? 'Ouvindo…'
                        : 'Toque no microfone ou digite sua busca.',
                  ),
                ),
              ],
            ),
            if (command != null && error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(command!.summary),
                ),
              ),
            if (error != null) Text(error!, semanticsLabel: error),
            if (conversationMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(conversationMessage!),
                ),
              ),
            if (conversation.pendingRoute != null)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy || listening
                          ? null
                          : () {
                              final p = conversation.pendingRoute!;
                              conversation.pendingRoute = null;
                              openRoute(p);
                              setState(() {
                                conversationMessage = null;
                              });
                            },
                      child: const Text('Calcular rota'),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        conversation.pendingRoute = null;
                        conversationMessage =
                            'Diga outro destino ou escolha um resultado.';
                      });
                    },
                    child: const Text('Outro destino'),
                  ),
                ],
              ),
            FilledButton(
              onPressed: busy || listening ? null : run,
              child: Text(busy ? 'Consultando…' : 'Pesquisar comando'),
            ),
            if (ran && command!.coupons)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Vigência publicada para planejamento. Dias, horários, regras e estoque precisam ser confirmados na emissão. Esta consulta não emite nem reserva cupons.',
                ),
              ),
            if (ran && found.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  command!.coupons
                      ? 'Nenhuma oferta publicada com vigência compatível encontrada para esta consulta.'
                      : 'Nenhum local encontrado. Revise o nome ou o município.',
                ),
              ),
            if (found.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: found.length,
                  itemBuilder: (context, i) {
                    final p = found[i], offer = offers[p.id];
                    return ListTile(
                      title: Text('${i + 1}. ${p.name}'),
                      subtitle: Text(
                        '${p.city}${nearOrigin == null ? '' : ' • ${nearOrigin!.distanceKm(p.point).toStringAsFixed(1)} km em linha reta'}${approximateIds.contains(p.id) ? ' • nome aproximado' : ''}${offer == null ? '' : ' • ${offer.title}'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Planejar rota para ${p.name}',
                        icon: const Icon(Icons.directions_outlined),
                        onPressed: () => chooseDestination(p),
                      ),
                      onTap: () {
                        if (command?.route == true) {
                          chooseDestination(p);
                          return;
                        }
                        widget.onFocus(p);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
