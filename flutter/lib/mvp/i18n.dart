import 'i18n_en.dart';

/// Idioma da interface ('pt' ou 'en'), definido pelo MvpApp a cada build.
String appLang = 'pt';

/// Traduz um texto da interface. O português é a chave; sem tradução, fica
/// em português (melhor que vazio).
String tr(String pt) => appLang == 'en' ? (enTexts[pt] ?? pt) : pt;

/// Turno ou período de uma reserva ("Manhã", "Tarde", "2 noites · Quarto").
/// O valor salvo no banco fica em português; aqui só muda o que aparece.
String trPeriod(String p) {
  if (appLang != 'en') return p;
  final m = RegExp(r'^(\d+) noites? · (.*)$').firstMatch(p);
  if (m != null) return '${m[1]} ${m[1] == '1' ? 'night' : 'nights'} · ${tr(m[2]!)}';
  return tr(p);
}
