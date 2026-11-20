
import 'vector_support_stub.dart'
    if (dart.library.js_interop) 'vector_support_web.dart'
    as vector;

abstract final class AppConfig {
  /// Mostra atalhos de demonstração (ex.: simular leitura do QR).
  /// Ligue com --dart-define=DEMO=true; em modo debug fica sempre ligado.
  static const demoMode = bool.fromEnvironment('DEMO');
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
  /// WhatsApp do atendimento humano do MaraPass (DDD + número, só dígitos).
  /// Defina com --dart-define=SUPPORT_WHATSAPP=98999999999.
  /// Site público com as páginas legais (/legal/...). No lançamento, passar
  /// `--dart-define=SITE_URL=https://marapass.com`.
  static const siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://teste.marapass.com',
  );
  static const supportWhatsapp = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
    defaultValue: '98984334256',
  );
  static const supabaseUrl =String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const onlineStyle = String.fromEnvironment(
    'MAPLIBRE_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );
  // Deve apontar para uma fonte contratada/licenciada para download em lote.
  static const offlineStyle = String.fromEnvironment(
    'LICENSED_OFFLINE_STYLE_URL',
  );
}
