import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/routing_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'prioriza voz brasileira premium e usa ritmo móvel mais rápido',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getVoices') {
          return [
            {'name': 'Outra', 'locale': 'pt-PT', 'quality': 'premium'},
            {'name': 'Padrão', 'locale': 'pt-BR', 'quality': 'default'},
            {'name': 'Aprimorada', 'locale': 'pt-BR', 'quality': 'enhanced'},
            {
              'name': 'Premium',
              'locale': 'pt-BR',
              'quality': 'premium',
              'identifier': 'br',
            },
          ];
        }
        return 1;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final routing = RoutingRepository();
      final navigation = NavigationSession(routing);
      addTearDown(routing.client.close);
      addTearDown(navigation.dispose);

      await navigation.setVoice(true);
      expect(
        calls.singleWhere((c) => c.method == 'setLanguage').arguments,
        'pt-BR',
      );
      expect(
        calls.singleWhere((c) => c.method == 'setSpeechRate').arguments,
        .56,
      );
      expect(
        calls
            .singleWhere((c) => c.method == 'setVoice')
            .arguments['identifier'],
        'br',
      );
      expect(
        calls.singleWhere((c) => c.method == 'speak').arguments,
        contains('vire à direita'),
      );

      await navigation.setVoice(false);
      await navigation.setVoice(true);
      expect(calls.where((c) => c.method == 'setSpeechRate'), hasLength(1));
    },
  );

  test(
    'silenciar durante a configuração cancela a instrução pendente',
    () async {
      final started = Completer<void>();
      final release = Completer<List<dynamic>>();
      final spoken = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getVoices') {
          started.complete();
          return release.future;
        }
        if (call.method == 'speak') spoken.add(call.arguments as String);
        return 1;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final routing = RoutingRepository();
      final navigation = NavigationSession(routing);
      addTearDown(routing.client.close);
      addTearDown(navigation.dispose);

      final enabling = navigation.setVoice(true);
      await started.future;
      await navigation.setVoice(false);
      release.complete([]);
      await enabling;
      expect(spoken, isEmpty);
    },
  );
}
