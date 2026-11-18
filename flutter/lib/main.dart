import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/map_state.dart';
import 'core/config.dart';
import 'mvp/auth/auth.dart';
import 'mvp/data/demo_repository.dart';
import 'mvp/data/remote.dart';
import 'mvp/data/repository.dart';
import 'mvp/data/store.dart';
import 'mvp/data/supabase_repository.dart';
import 'mvp/providers.dart';
import 'mvp/ui/app.dart';
import 'data/tourism_repository.dart';
import 'presentation/map_screen.dart';
import 'presentation/brand.dart';
import 'presentation/editorial_preview.dart';
import 'pilot/barreirinhas.dart';

/// `--dart-define=MVP_DEMO=true` força dados fictícios (sem Supabase).
const _forceDemo = bool.fromEnvironment('MVP_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Acessibilidade na web: o Flutter liga a árvore sob demanda, quando um
  // leitor de tela é usado. Ligar sempre deixava o iPhone lento e travava
  // a digitação nos campos de texto do Safari.
  final repo = TourismRepository(await SharedPreferences.getInstance());

  // O mapa original continua acessível por parâmetros de URL (prévia
  // editorial, piloto de Barreirinhas e ?legacy=1). O padrão é o app novo.
  final q = Uri.base.queryParameters;
  final legacy =
      q['cms-preview'] == '1' ||
      q['pilot'] == 'barreirinhas' ||
      q['legacy'] == '1';
  // O app novo abre na hora; o catálogo pesado do mapa (lugares, relevo,
  // estradas de referência) carrega em segundo plano.
  if (legacy) {
    await repo.ensureLoaded();
  } else {
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 4),
        () => repo.ensureLoaded(withRoads: false),
      ),
    );
  }

  final overrides = <Override>[repositoryProvider.overrideWithValue(repo)];
  final Widget app;
  if (legacy) {
    app = const MaraPassApp();
  } else {
    final backend = await _initBackend();
    final store = await AppStore.load(
      remote: backend.$1 is SupabaseMvpRepository
          ? MvpRemote(Supabase.instance.client)
          : null,
    );
    unawaited(store.syncFromServer());
    overrides.addAll([
      appStoreProvider.overrideWith((ref) => store),
      mvpRepositoryProvider.overrideWithValue(backend.$1),
      authGatewayProvider.overrideWithValue(backend.$2),
    ]);
    // Na web, a abertura animada roda em HTML/CSS enquanto o Flutter carrega
    // (fluida no Safari); no app instalado, a versão em Flutter.
    app = kIsWeb ? const MvpApp(splash: Duration.zero) : const MvpApp();
  }
  runApp(ProviderScope(overrides: overrides, child: app));
}

/// Supabase quando há URL e chave publicável; senão, modo demonstração.
Future<(MvpRepository, AuthGateway)> _initBackend() async {
  if (!_forceDemo &&
      AppConfig.supabaseUrl.isNotEmpty &&
      AppConfig.publishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.publishableKey,
      );
      final client = Supabase.instance.client;
      return (SupabaseMvpRepository(client), SupabaseAuthGateway(client));
    } catch (_) {
      // cai para a demonstração em vez de abrir uma tela quebrada
    }
  }
  return (DemoMvpRepository(), DemoAuthGateway());
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
