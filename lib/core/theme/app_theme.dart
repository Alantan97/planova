import 'package:flutter/material.dart';

const planovaOrange = Color(0xFFFF6600);
// Deeper orange keeps white button text and orange labels readable.
const planovaActionOrange = Color(0xFFC74700);
const planovaInk = Color(0xFF111111);
const planovaMuted = Color(0xFF5F6672);
const planovaBorder = Color(0xFFE6E6E6);
const planovaSurface = Color(0xFFF7F8FA);
// Brand rule: orange surfaces always use white text and icons.
const planovaOnOrange = Colors.white;

ThemeData buildPlanovaTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: planovaOrange,
    primary: planovaActionOrange,
    onPrimary: planovaOnOrange,
    secondary: planovaActionOrange,
    onSecondary: planovaOnOrange,
    tertiary: planovaInk,
    surface: Colors.white,
    surfaceTint: Colors.transparent,
  ),
  scaffoldBackgroundColor: Colors.white,
  // Material 3 tints a scrolled app bar with the seed colour (light peach);
  // keep it white like the page and use a hairline shadow instead.
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 1,
    shadowColor: planovaBorder,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: planovaSurface,
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
  ),
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: planovaInk,
    displayColor: planovaInk,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: planovaActionOrange,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: planovaInk,
      minimumSize: const Size(0, 48),
      side: const BorderSide(color: planovaBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: planovaInk,
      minimumSize: const Size(48, 48),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Colors.transparent,
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? planovaActionOrange
            : planovaInk,
        size: 28,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 12,
        color: states.contains(WidgetState.selected)
            ? planovaActionOrange
            : planovaInk,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    ),
  ),
);
