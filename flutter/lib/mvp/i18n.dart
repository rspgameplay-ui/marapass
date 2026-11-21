import 'i18n_en.dart';

/// Idioma da interface ('pt' ou 'en'), definido pelo MvpApp a cada build.
String appLang = 'pt';

/// Traduz um texto da interface. O português é a chave; sem tradução, fica
/// em português (melhor que vazio).
String tr(String pt) => appLang == 'en' ? (enTexts[pt] ?? pt) : pt;
