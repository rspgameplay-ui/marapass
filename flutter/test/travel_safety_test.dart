import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/presentation/travel_safety.dart';

void main() {
  testWidgets('abre dicas locais e permite consultar cada etapa', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: TravelSafetyButton(
            stage: SafetyStage.arrival,
            barreirinhas: true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.text('Barreirinhas · Lençóis Maranhenses'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('credenciamento'), 140);
    expect(find.textContaining('credenciamento'), findsOneWidget);

    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'No transporte'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('banco traseiro'), 140);
    expect(find.textContaining('banco traseiro'), findsOneWidget);

    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'No passeio'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('colete salva-vidas'),
      140,
    );
    expect(find.textContaining('colete salva-vidas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
