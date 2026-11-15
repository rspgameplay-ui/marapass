import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/maps/pointer_shield.dart';

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => taps++),
    child: Text('toques $taps'),
  );
}

Widget host(bool enabled) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: PointerShield(enabled: enabled, child: const _Counter()),
    ),
  ),
);

void main() {
  testWidgets('controle protegido recebe toques e mantém estado ao alternar', (
    tester,
  ) async {
    await tester.pumpWidget(host(false));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('toques 1'), findsOneWidget);
    // Entrar no 3D liga a proteção: o controle não pode ser recriado.
    await tester.pumpWidget(host(true));
    expect(find.text('toques 1'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('toques 2'), findsOneWidget);
    await tester.pumpWidget(host(false));
    expect(find.text('toques 2'), findsOneWidget);
  });
}
