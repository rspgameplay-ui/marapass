// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get navHome => 'Início';

  @override
  String get navMap => 'Mapa';

  @override
  String get navCoupons => 'Cupons';

  @override
  String get navPassport => 'Passaporte';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSubtitle => 'Português ou inglês';

  @override
  String get supportChannelsTitle => 'Canais de atendimento';

  @override
  String get supportPhone => 'Telefone';

  @override
  String supportPhoneHours(String phone) {
    return '$phone · seg a sáb, 8h às 20h';
  }

  @override
  String get supportEmail => 'E-mail';

  @override
  String get supportWhatsapp => 'WhatsApp';

  @override
  String get supportWhatsappSubtitle => 'Mensagem pronta com o seu protocolo';

  @override
  String get supportWhatsappMessage => 'Olá! Preciso de ajuda com o MaraPass.';

  @override
  String get supportSafetyNotice =>
      'No WhatsApp, informe o número do protocolo. Nunca envie senhas, códigos de login ou dados de cartão.';
}
