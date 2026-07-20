import 'package:flutter/material.dart';

abstract final class TripColors {
  static const ink = Color(0xFF27231F);
  static const paper = Color(0xFFF6F0E5);
  static const paperDeep = Color(0xFFECE1D0);
  static const paprika = Color(0xFFCD5334);
  static const paprikaDark = Color(0xFF8E301F);
  static const moss = Color(0xFF52644D);
  static const indigo = Color(0xFF30455B);
  static const sun = Color(0xFFF0B552);
  static const success = Color(0xFF3E6E51);
  static const danger = Color(0xFFA63D2D);
}

ThemeData buildTheme() {
  const colorScheme = ColorScheme.light(
    primary: TripColors.paprika,
    onPrimary: Color(0xFFFFF8EE),
    secondary: TripColors.moss,
    onSecondary: Color(0xFFF7F3E9),
    surface: TripColors.paper,
    onSurface: TripColors.ink,
    error: TripColors.danger,
    onError: Color(0xFFFFF7F2),
    outline: Color(0xFF9C8E7C),
    outlineVariant: Color(0xFFD8CCBC),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: TripColors.paper,
    fontFamily: 'Manrope',
    fontFamilyFallback: const ['NotoSansSC'],
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: 'Fraunces',
            fontFamilyFallback: ['NotoSansSC'],
            fontSize: 64,
            height: .98,
            fontWeight: FontWeight.w600,
            letterSpacing: -2.2,
          ),
          displayMedium: const TextStyle(
            fontFamily: 'Fraunces',
            fontFamilyFallback: ['NotoSansSC'],
            fontSize: 46,
            height: 1.02,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.3,
          ),
          headlineLarge: const TextStyle(
            fontFamily: 'Fraunces',
            fontFamilyFallback: ['NotoSansSC'],
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'Fraunces',
            fontFamilyFallback: ['NotoSansSC'],
            fontSize: 27,
            height: 1.12,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.25,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
          ),
        )
        .apply(bodyColor: TripColors.ink, displayColor: TripColors.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: TripColors.ink, width: 1.2),
        shape: const StadiumBorder(),
        foregroundColor: TripColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size.square(44)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: TripColors.paprika,
      inactiveTrackColor: TripColors.paperDeep,
      thumbColor: TripColors.paprika,
      overlayColor: Color(0x22CD5334),
      trackHeight: 5,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFD8CCBC),
      thickness: 1,
    ),
  );
}
