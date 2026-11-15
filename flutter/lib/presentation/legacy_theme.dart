import 'package:flutter/material.dart';

import 'brand.dart';

/// Tema do mapa turístico original. O mapa é aberto de dentro do app novo
/// (que tem tema próprio), então envolvemos a rota com este tema.
ThemeData legacyMapTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: MaraColors.navy,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: MaraColors.background,
  fontFamily: 'MaraSans',
  inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
);
