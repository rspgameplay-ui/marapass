import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// `--dart-define=MVP_DEMO=true` força dados fictícios (sem Supabase).
const _forceDemo = bool.fromEnvironment('MVP_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Acessibilidade na web: o Flutter liga a árvore sob demanda, quando um
  // leitor de tela é usado. Ligar sempre deixava o iPhone lento e travava
  // a digitação nos campos de texto do Safari.
  final repo = TourismRepository(await SharedPreferences.getInstance());

  // O app abre na hora; o catálogo pesado do mapa (lugares, relevo,
  // estradas de referência) carrega em segundo plano.
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 4),
      () => repo.ensureLoaded(withRoads: false),
    ),
  );

  final backend = await _initBackend();
  final store = await AppStore.load(
    remote: backend.$1 is SupabaseMvpRepository
        ? MvpRemote(Supabase.instance.client, await SharedPreferences.getInstance())
        : null,
  );
  unawaited(store.syncFromServer());
  // Na web, a abertura animada roda em HTML/CSS enquanto o Flutter carrega
  // (fluida no Safari); no app instalado, a versão em Flutter.
  final app = kIsWeb ? const MvpApp(splash: Duration.zero) : const MvpApp();
  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        appStoreProvider.overrideWith((ref) => store),
        mvpRepositoryProvider.overrideWithValue(backend.$1),
        authGatewayProvider.overrideWithValue(backend.$2),
      ],
      child: app,
    ),
  );
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
      return (SupabaseMvpRepository(client, await SharedPreferences.getInstance()), SupabaseAuthGateway(client));
    } catch (_) {
      // cai para a demonstração em vez de abrir uma tela quebrada
    }
  }
  return (DemoMvpRepository(), DemoAuthGateway());
}
