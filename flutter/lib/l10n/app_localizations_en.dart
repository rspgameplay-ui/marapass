// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navMap => 'Map';

  @override
  String get navCoupons => 'Coupons';

  @override
  String get navPassport => 'Passport';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Portuguese or English';

  @override
  String get supportChannelsTitle => 'Support channels';

  @override
  String get supportPhone => 'Phone';

  @override
  String supportPhoneHours(String phone) {
    return '$phone · Mon to Sat, 8am to 8pm';
  }

  @override
  String get supportEmail => 'Email';

  @override
  String get supportWhatsapp => 'WhatsApp';

  @override
  String get supportWhatsappSubtitle =>
      'Ready-made message with your ticket number';

  @override
  String get supportWhatsappMessage => 'Hello! I need help with MaraPass.';

  @override
  String get supportSafetyNotice =>
      'On WhatsApp, give your ticket number. Never send passwords, login codes or card details.';
}
