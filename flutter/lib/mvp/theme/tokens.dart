import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Design system MaraPass acessível.
///
/// Cores: tokens do Design Master (Figma). Escala e layout: protótipo aprovado
/// pelo cliente (letras grandes, botões largos, fotos reais, poucas etapas),
/// pensado também para pessoas mais velhas.
abstract final class MP {
  // Marca (Figma)
  static const green = Color(0xff14775a);
  static const greenPressed = Color(0xff0e5a44);
  static const greenBg = Color(0xffe7f4ee);
  static const navy = Color(0xff0b3a66);
  static const ink = Color(0xff13263d);
  static const gold = Color(0xffd4a017);
  static const yellow = Color(0xfffac61d);
  static const goldBg = Color(0xfffdf3d3);

  static const goldText = Color(0xffa87b00); // dourado legível sobre branco
  static const onDarkMuted = Color(0xffc9d6e3); // texto secundário sobre azul-escuro
  static const onBlueMuted = Color(0xffc9d9f7); // texto secundário sobre azul vivo
  static const scanBg = Color(0xff07121f); // fundo do leitor sem câmera
  static const ticket = Color(0xff2b5fc4); // azul do bilhete do passaporte
  static const ticketDark = Color(0xff1d46a0);
  static const ticketTrack = Color(0xffdbe5f8);

  // Paleta do calendário de temporadas e das categorias do mapa
  static const seasonOrange = Color(0xffe8812f);
  static const seasonRed = Color(0xffd9534f);
  static const seasonPurple = Color(0xff7b3fa8);
  static const seasonBlue = Color(0xff2f7fb8);
  static const seasonTeal = Color(0xff2a9d8f);
  static const seasonGreen = Color(0xff48a868);
  static const seasonYellow = Color(0xfff5c428);
  static const seasonSand = Color(0xffd9a441);
  static const seasonNight = Color(0xff1b2a3b);
  static const poiIsland = Color(0xff2e7d6f);
  static const poiBeach = Color(0xff0f8fa8);
  static const poiTour = Color(0xff1f6fd1);
  static const poiStay = Color(0xff6a4fb3);
  static const poiEvent = Color(0xffb0407e);
  static const poiCraft = Color(0xffa87800);
  static const poiCulture = Color(0xff8a5a2b);
  static const routeBlue = Color(0xff1a73e8);

  // Superfícies
  static const page = Color(0xffffffff);
  static const soft = Color(0xfff3f5f7);
  static const card = Color(0xffffffff);
  static const subtle = Color(0xffeeecea);
  static const border = Color(0xffdce2e8);
  static const borderSubtle = Color(0xffeef1f4);

  // Texto (contraste AA sobre branco)
  static const text = Color(0xff2c3e52);
  static const textSecondary = Color(0xff556677);
  static const textMuted = Color(0xff7b8794);
  static const textInverse = Color(0xffffffff);

  // Estados
  static const success = Color(0xff16a34a);
  static const successBg = Color(0xffdcfce7);
  static const warning = Color(0xffb45309);
  static const warningBg = Color(0xfffef3c7);
  static const error = Color(0xffc53b36);
  static const errorBg = Color(0xfffee2e2);
  static const info = Color(0xff2563eb);
  static const infoBg = Color(0xffdbeafe);

  // Cores de apoio dos atalhos (fundo pastel + ícone)
  static const tintBlue = Color(0xffe6eefb);
  static const tintYellow = Color(0xfffdf1cf);
  static const tintGreen = Color(0xffe3f3ea);
  static const tintPurple = Color(0xffeee8fb);
  static const tintRed = Color(0xfffde5e3);

  // Espaçamento
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const pageH = 20.0;
  static const sectionGap = 28.0;

  // Raios
  static const rSmall = 10.0;
  static const rMedium = 14.0;
  static const rLarge = 18.0;
  static const rXl = 22.0;
  static const rPill = 999.0;

  // Ícones (uma família: Material Rounded)
  static const iconSm = 20.0;
  static const iconMd = 24.0;
  static const iconLg = 28.0;

  // Sombras suaves (elevação discreta, sem borrão pesado)
  static const shadowCard = [
    BoxShadow(color: Color(0x0f13263d), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const shadowFloat = [
    BoxShadow(color: Color(0x2413263d), blurRadius: 18, offset: Offset(0, 6)),
  ];

  // Durações de interação
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);

  /// Alvo de toque: 48 px (o design pede no mínimo 44).
  static const minTap = 48.0;
  static const buttonHeight = 56.0;
}

const mpFont = 'Jakarta';

ThemeData mvpTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MP.green,
    primary: MP.green,
    onPrimary: MP.textInverse,
    secondary: MP.navy,
    surface: MP.card,
    error: MP.error,
  );
  OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(MP.rMedium),
    borderSide: BorderSide(color: c, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: mpFont,
    scaffoldBackgroundColor: MP.page,
    visualDensity: VisualDensity.standard,
    // Sensação de app: telas deslizam como no iPhone e o toque é discreto.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
    splashFactory: InkRipple.splashFactory,
    highlightColor: const Color(0x0a13263d),
    splashColor: const Color(0x1413263d),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: const AppBarTheme(
      backgroundColor: MP.page,
      foregroundColor: MP.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        fontFamily: mpFont,
        color: MP.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: MP.ink,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: MP.ink,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: MP.ink,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: MP.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: MP.ink,
        height: 1.3,
      ),
      bodyLarge: TextStyle(fontSize: 17, color: MP.text, height: 1.5),
      bodyMedium: TextStyle(fontSize: 16, color: MP.text, height: 1.5),
      bodySmall: TextStyle(fontSize: 14, color: MP.textSecondary, height: 1.45),
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: MP.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: MP.textSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MP.soft,
      hintStyle: const TextStyle(color: MP.textMuted, fontSize: 16),
      labelStyle: const TextStyle(color: MP.textSecondary, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: border(MP.border),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(MP.green, 2),
      errorBorder: border(MP.error),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        overlayColor: Colors.white,
        backgroundColor: MP.navy,
        foregroundColor: MP.textInverse,
        disabledBackgroundColor: MP.border,
        disabledForegroundColor: MP.textMuted,
        minimumSize: const Size.fromHeight(MP.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MP.rMedium),
        ),
        textStyle: const TextStyle(
          fontFamily: mpFont,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        overlayColor: MP.navy,
        foregroundColor: MP.navy,
        backgroundColor: MP.soft,
        minimumSize: const Size.fromHeight(MP.buttonHeight),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MP.rMedium),
        ),
        textStyle: const TextStyle(
          fontFamily: mpFont,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MP.green,
        minimumSize: const Size(MP.minTap, MP.minTap),
        textStyle: const TextStyle(
          fontFamily: mpFont,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MP.soft,
      selectedColor: MP.navy,
      labelStyle: const TextStyle(
        fontFamily: mpFont,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: MP.ink,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: mpFont,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MP.rPill),
      ),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MP.page,
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xffe3f1ff),
      indicatorShape: const StadiumBorder(),
      height: 70,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      shadowColor: Colors.black26,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: mpFont,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          letterSpacing: -.2,
          color: s.contains(WidgetState.selected) ? MP.navy : MP.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 26,
          color: s.contains(WidgetState.selected) ? MP.navy : MP.textMuted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? MP.green : null,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: MP.ink,
      contentTextStyle: const TextStyle(
        fontFamily: mpFont,
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MP.rMedium),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MP.page,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MP.rXl),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: mpFont,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: MP.ink,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: mpFont,
        fontSize: 16,
        color: MP.text,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MP.page,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MP.rXl)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: MP.borderSubtle,
      thickness: 1,
      space: 1,
    ),
  );
}
