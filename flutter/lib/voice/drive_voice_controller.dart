import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/tourism.dart';
import 'drive_command.dart';
import 'speech_engine.dart';

class DriveVoiceController extends ChangeNotifier {
  DriveVoiceController({
    required this.active,
    required this.speaking,
    required this.resolve,
    required this.change,
    required this.speak,
  });

  final bool Function() active, speaking;
  final List<TourismPlace> Function(String) resolve;
  final Future<bool> Function(TourismPlace) change;
  final Future<void> Function(String) speak;

  static const hint = 'Diga: “Marapés, mude o destino para…”';
  bool enabled = false, _busy = false;
  String? status;
  TourismPlace? pending;
  bool get canConfirm => enabled && pending != null && !_busy;
  Timer? _restart, _expiry;
  int _revision = 0;

  Future<void> toggle() async {
    if (enabled) {
      stop();
      return;
    }
    if (!active()) return;
    enabled = true;
    status = hint;
    final revision = ++_revision;
    notifyListeners();
    mapSpeechEngine.onStatus = (value) {
      if (value == SpeechToText.doneStatus) _schedule(revision);
    };
    mapSpeechEngine.onError = (error) {
      if (!_current(revision) || _busy) return;
      if (const {
        'error_no_match',
        'error_speech_timeout',
        'no-speech',
        'aborted',
      }.contains(error)) {
        _schedule(revision);
      } else {
        stop('Microfone indisponível. A rota atual continua.');
      }
    };
    try {
      final ready = await mapSpeechEngine.initialize();
      if (!_current(revision)) return;
      if (!ready) {
        stop('Autorize o microfone em um navegador compatível.');
        return;
      }
      await _listen(revision);
    } catch (_) {
      if (_current(revision)) stop('Não foi possível ativar o microfone.');
    }
  }

  bool _current(int revision) => revision == _revision && enabled && active();

  void _schedule(int revision) {
    if (!_current(revision) || _busy) return;
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 700), () {
      if (speaking()) {
        _schedule(revision);
      } else {
        unawaited(_listen(revision));
      }
    });
  }

  Future<void> _listen(int revision) async {
    if (!_current(revision) || _busy || mapSpeechEngine.speech.isListening) {
      return;
    }
    if (speaking()) {
      _schedule(revision);
      return;
    }
    try {
      await mapSpeechEngine.speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'pt-BR',
          onDevice: !kIsWeb,
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 5),
          partialResults: false,
          cancelOnError: false,
        ),
        onResult: (result) {
          if (!result.finalResult || !_current(revision) || _busy || speaking()) {
            return;
          }
          final text = result.recognizedWords;
          if (pending != null && confirmsDriveDestination(text)) {
            unawaited(confirm());
          } else if (pending != null && cancelsDriveDestination(text)) {
            unawaited(cancel());
          } else if (driveDestination(text) case final term?) {
            unawaited(
              _exchange(revision, () async {
                pending = null;
                final matches = resolve(term);
                if (matches.isEmpty) {
                  return 'Não encontrei o destino. Diga o nome e a cidade.';
                }
                if (matches.length != 1) {
                  return 'Encontrei mais de um lugar. Diga o nome completo e a cidade.';
                }
                final destination = matches.single;
                if (destination.needsVisitPlanning) {
                  return 'Esse local exige planejamento de visita. Mantive a rota atual.';
                }
                pending = destination;
                final name = destination.name == destination.city
                    ? destination.name
                    : '${destination.name}, em ${destination.city}';
                return 'Mudar o destino para $name? Diga sim ou cancelar.';
              }),
            );
          } else {
            _schedule(revision);
          }
        },
      );
    } catch (_) {
      if (_current(revision)) {
        stop('Escuta interrompida. A rota atual continua.');
      }
    }
  }

  Future<void> confirm() async {
    final destination = pending;
    if (destination == null) return;
    await _exchange(_revision, () async {
      pending = null;
      status = 'Calculando rota para ${destination.name}…';
      notifyListeners();
      return await change(destination)
          ? 'Nova rota para ${destination.name}.'
          : 'Não consegui mudar o destino. Mantive a rota atual.';
    });
  }

  Future<void> cancel() => _exchange(_revision, () async {
    pending = null;
    return 'Mantive a rota atual.';
  });

  Future<void> _exchange(int revision, Future<String> Function() act) async {
    if (!_current(revision) || _busy) return;
    _busy = true;
    _restart?.cancel();
    _expiry?.cancel();
    try {
      await mapSpeechEngine.speech.cancel();
      if (!_current(revision)) return;
      final reply = await act();
      if (!_current(revision)) return;
      status = reply;
      notifyListeners();
      await speak(reply);
      if (!_current(revision)) return;
      _expiry = Timer(const Duration(seconds: 18), () {
        if (!_current(revision)) return;
        pending = null;
        status = hint;
        notifyListeners();
      });
    } catch (_) {
      if (_current(revision)) stop('Comandos por voz interrompidos.');
    } finally {
      if (_current(revision)) {
        _busy = false;
        notifyListeners();
        _schedule(revision);
      }
    }
  }

  void stop([String? message]) {
    if (!enabled) return;
    _release();
    status = message;
    notifyListeners();
  }

  void _release() {
    ++_revision;
    enabled = _busy = false;
    pending = null;
    _restart?.cancel();
    _expiry?.cancel();
    mapSpeechEngine.onStatus = mapSpeechEngine.onError = null;
    unawaited(mapSpeechEngine.speech.cancel().catchError((Object _) {}));
  }

  @override
  void dispose() {
    if (enabled) _release();
    super.dispose();
  }
}
