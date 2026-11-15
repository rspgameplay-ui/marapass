import 'package:speech_to_text/speech_to_text.dart';

/// Plugin callbacks are installed once. Forward them to the currently open sheet.
class MapSpeechEngine {
  final SpeechToText speech = SpeechToText();
  Future<bool>? _initialization;
  void Function(String)? onStatus, onError;
  Future<bool> initialize() async {
    final ready = await (_initialization ??= speech.initialize(
      onStatus: (s) => onStatus?.call(s),
      onError: (e) => onError?.call(e.errorMsg),
    ));
    if (!ready) _initialization = null;
    return ready;
  }
}

final mapSpeechEngine = MapSpeechEngine();
