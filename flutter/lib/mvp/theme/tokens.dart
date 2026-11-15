import 'package:flutter/material.dart';

/// Tokens do Design Master (Figma): conjuntos MaraPass / Color, Spacing e Radius.
abstract final class MP {
  // Marca
  static const green = Color(0xff176b54);
  static const greenPressed = Color(0xff0f4a3a);
  static const navy = Color(0xff1a3a5c);
  static const gold = Color(0xffd4a017);

  // Superfícies e bordas
  static const page = Color(0xfff8f7f4);
  static const card = Color(0xffffffff);
  static const subtle = Color(0xffeeecea);
  static const border = Color(0xffe5e3df);
  static const borderSubtle = Color(0xfff0efec);

  // Texto
  static const text = Color(0xff1a1a1a);
  static const textSecondary = Color(0xff6b7280);
  static const textMuted = Color(0xff9ca3af);
  static const textInverse = Color(0xffffffff);

  // Estados
  static const success = Color(0xff16a34a);
  static const successBg = Color(0xffdcfce7);
  static const warning = Color(0xffd97706);
  static const warningBg = Color(0xfffef3c7);
  static const error = Color(0xffdc2626);
  static const errorBg = Color(0xfffee2e2);
  static const info = Color(0xff2563eb);
  static const infoBg = Color(0xffdbeafe);

  // Espaçamento
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const pageH = 16.0;
  static const sectionGap = 24.0;

  // Raios
  static const rSmall = 8.0;
  static const rMedium = 12.0;
  static const rLarge = 16.0;
  static const rXl = 20.0;
  static const r2xl = 24.0;
  static const rPill = 999.0;

  /// Alvo de toque mínimo exigido pelo QA do design.
  static const minTap = 44.0;
}

const _font = 'MaraSans';

ThemeData mvpTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MP.green,
    primary: MP.green,
    onPrimary: MP.textInverse,
    secondary: MP.navy,
    surface: MP.card,
    error: MP.error,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _font,
    scaffoldBackgroundColor: MP.page,
    appBarTheme: const AppBarTheme(
      backgroundColor: MP.page,
      foregroundColor: MP.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        color: MP.navy,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: MP.navy,
        height: 1.1,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: MP.navy,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: MP.text,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: MP.text, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: MP.textSecondary, height: 1.4),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: MP.textSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MP.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MP.rMedium),
        borderSide: const BorderSide(color: MP.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MP.rMedium),
        borderSide: const BorderSide(color: MP.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MP.rMedium),
        borderSide: const BorderSide(color: MP.green, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MP.green,
        foregroundColor: MP.textInverse,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MP.rMedium),
        ),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MP.navy,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: MP.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MP.rMedium),
        ),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MP.card,
      indicatorColor: MP.green.withValues(alpha: .12),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: _font,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? MP.green
              : MP.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? MP.green
              : MP.textSecondary,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: MP.navy,
      contentTextStyle: const TextStyle(fontFamily: _font, color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MP.rMedium),
      ),
    ),
  );
}
