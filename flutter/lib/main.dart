import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/map_state.dart';
import 'data/tourism_repository.dart';
import 'presentation/map_screen.dart';
import 'presentation/brand.dart';
import 'presentation/editorial_preview.dart';
import 'pilot/barreirinhas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = TourismRepository(await SharedPreferences.getInstance());
  await repo.initialize();
  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: const MaraPassApp(),
    ),
  );
}

class MaraPassApp extends StatelessWidget {
  const MaraPassApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MaraPass • Mapa turístico',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    themeMode: ThemeMode.light,
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MaraColors.navy,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: MaraColors.background,
      fontFamily: 'MaraSans',
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff5ebcb3),
        brightness: Brightness.dark,
      ),
    ),
    home: Uri.base.queryParameters['cms-preview'] == '1'
        ? const EditorialPreview()
        : Uri.base.queryParameters['pilot'] == 'barreirinhas'
        ? const BarreirinhasPilot()
        : const MapScreen(),
  );
}
