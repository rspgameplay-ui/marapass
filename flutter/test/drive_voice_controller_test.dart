import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/voice/drive_voice_controller.dart';

void main() {
  testWidgets('Marapés confirma destino por toque e por voz', (tester) async {
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    const codec = StandardMethodCodec();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Future<void> send(String method, Object arguments) async {
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
      await tester.pump();
    }

    Future<void> utterance(String words) async {
      await send('notifyStatus', 'listening');
      await send(
        'textRecognition',
        jsonEncode({
          'resultType': 2,
          'alternates': [
            {'recognizedWords': words, 'confidence': .99},
          ],
        }),
      );
    }

    const target = TourismPlace(
      id: 'barreirinhas',
      name: 'Barreirinhas',
      city: 'Barreirinhas',
      point: GeoPoint(-2.75, -42.83),
      category: PlaceCategory.destination,
      description: '',
    );
    final destinations = <TourismPlace>[];
    final assistant = DriveVoiceController(
      active: () => true,
      speaking: () => false,
      resolve: (name) => name == 'barreirinhas' ? [target] : [],
      change: (place) async {
        destinations.add(place);
        return true;
      },
      speak: (_) async {},
    );

    await assistant.toggle();
    await utterance('Marapés, mude o destino para Barreirinhas');
    expect(assistant.pending, target);
    expect(destinations, isEmpty);
    await assistant.confirm();
    expect(destinations, [target]);

    await tester.pump(const Duration(milliseconds: 750));
    await utterance('Marapés, me leve até Barreirinhas');
    expect(assistant.canConfirm, isTrue);
    await tester.pump(const Duration(milliseconds: 750));
    await utterance('Sim');
    expect(destinations, [target, target]);
    assistant.dispose();
    await tester.pump(const Duration(seconds: 30));
  });
}
