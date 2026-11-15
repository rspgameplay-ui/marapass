import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/tourism.dart';
import '../voice/speech_engine.dart';

/// Reconhece uma origem e exige seleção explícita entre os resultados.
class OriginVoiceSheet extends StatefulWidget {
  const OriginVoiceSheet({super.key, required this.places});
  final List<TourismPlace> places;
  @override
  State<OriginVoiceSheet> createState() => _OriginVoiceSheetState();
}

class _OriginVoiceSheetState extends State<OriginVoiceSheet> {
  String heard = '',
      message = 'Toque no microfone e diga a cidade ou o lugar de partida.';
  bool listening = false;
  @override
  void dispose() {
    mapSpeechEngine.onError = null;
    mapSpeechEngine.onStatus = null;
    mapSpeechEngine.speech.cancel();
    super.dispose();
  }

  Future<void> listen() async {
    if (listening) return;
    setState(() {
      message = 'Preparando microfone…';
      heard = '';
    });
    try {
      mapSpeechEngine.onError = (error) {
        if (!mounted) return;
        setState(() {
          listening = false;
          message =
              error.contains('permission') ||
                  error.contains('not_allowed') ||
                  error.contains('not-allowed')
              ? 'Microfone não autorizado. Permita o acesso ou digite a origem.'
              : 'Não consegui ouvir. Tente novamente ou digite a origem.';
        });
      };
      mapSpeechEngine.onStatus = (status) {
        if (mounted && status != 'listening')
          setState(() {
            listening = false;
            if (heard.isEmpty)
              message = 'Nada reconhecido. Tente novamente ou digite a origem.';
          });
      };
      final ready = await mapSpeechEngine.initialize();
      if (!mounted) return;
      if (!ready) {
        setState(
          () => message = 'Voz indisponível neste navegador. Digite a origem.',
        );
        return;
      }
      setState(() {
        listening = true;
        message = 'Ouvindo…';
      });
      await mapSpeechEngine.speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'pt-BR',
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            heard = result.recognizedWords;
            message = result.finalResult
                ? 'Confira o que entendi e escolha a origem.'
                : 'Ouvindo…';
            if (result.finalResult) listening = false;
          });
        },
      );
    } catch (_) {
      if (mounted)
        setState(() {
          listening = false;
          message = 'Não foi possível usar o microfone. Digite a origem.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = normalize(heard)
        .replaceFirst(
          RegExp(r'^(origem|saindo de|sair de|partindo de|partir de)\s+'),
          '',
        )
        .trim();
    final matches = q.length < 2
        ? <TourismPlace>[]
        : widget.places
              .where((p) => normalize('${p.name} ${p.city}').contains(q))
              .take(12)
              .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escolher origem por voz',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message),
            if (heard.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Entendi: $heard'),
              ),
            FilledButton.icon(
              onPressed: listening ? null : listen,
              icon: const Icon(Icons.mic_none),
              label: Text(listening ? 'Ouvindo…' : 'Falar origem'),
            ),
            if (heard.isNotEmpty && matches.isEmpty && !listening)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Não encontrei este lugar. Tente outro nome ou digite a origem.',
                ),
              ),
            if (matches.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in matches)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(p.name),
                        subtitle: Text(p.city),
                        onTap: () => Navigator.pop(context, p),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
