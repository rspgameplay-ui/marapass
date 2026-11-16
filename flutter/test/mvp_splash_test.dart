import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/theme/mara_logo.dart';
import 'package:marapass_mapa/mvp/ui/animated_splash.dart';

void main() {
  testWidgets('abertura dura cerca de 2,8 s e termina sozinha', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: AnimatedSplash(onDone: () => done++)));
    await tester.pump(const Duration(milliseconds: 2000));
    expect(done, 0);
    expect(find.text('MaraPass'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(done, 1);
  });

  testWidgets('um toque pula a abertura', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: AnimatedSplash(onDone: () => done++)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(AnimatedSplash));
    expect(done, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(done, 1);
  });

  testWidgets('logo vetorial nas variações do manual', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Column(children: [
        MaraPassLogo(size: 40),
        MaraPassLogo(size: 40, variant: MaraLogoVariant.horizontal),
        MaraPassLogo(size: 40, variant: MaraLogoVariant.stacked, onDark: true),
        MaraPassLogo(size: 40, mono: maraNight),
      ]),
    ));
    expect(find.text('MaraPass'), findsNWidgets(2));
    expect(maraBlades.length, 6);
  });
}
