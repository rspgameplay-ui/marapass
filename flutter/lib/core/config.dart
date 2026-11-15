import 'package:flutter/foundation.dart';

import 'vector_support_stub.dart'
    if (dart.library.js_interop) 'vector_support_web.dart'
    as vector;

abstract final class AppConfig {
  static final supportsVectorMaps = vector.supportsVectorMaps();
  static const routingUrl = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-car',
  );
  static const walkingRoutingUrl = String.fromEnvironment(
    'WALKING_ROUTING_BASE_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-foot',
  );
  static const controlCenterUrl = String.fromEnvironment(
    'CONTROL_CENTER_URL',
    defaultValue:
        'https://marapass-mapa-flutter-preview.dfamorim-10.chatgpt.site/admin/',
  );
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const googleReady = bool.fromEnvironment('GOOGLE_MAPS_READY');
  static const googleAndroidId = String.fromEnvironment(
    'GOOGLE_MAP_ID_ANDROID',
  );
  static const googleIosId = String.fromEnvironment('GOOGLE_MAP_ID_IOS');
  static const onlineStyle = String.fromEnvironment(
    'MAPLIBRE_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );
  // Deve apontar para uma fonte contratada/licenciada para download em lote.
  static const offlineStyle = String.fromEnvironment(
    'LICENSED_OFFLINE_STYLE_URL',
  );
  static bool get canUseGoogle =>
      !kIsWeb &&
      googleReady &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static String? get googleMapId {
    final id = defaultTargetPlatform == TargetPlatform.iOS
        ? googleIosId
        : googleAndroidId;
    return id.isEmpty ? null : id;
  }
}
