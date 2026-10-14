import 'package:flutter/material.dart';

const planovaOrange = Color(0xFFFF6600);
const planovaInk = Color(0xFF111111);
const planovaMuted = Color(0xFF5F6672);
// Brand rule: orange surfaces always use white text and icons.
const planovaOnOrange = Colors.white;

ThemeData buildPlanovaTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: planovaOrange,
    primary: planovaOrange,
    onPrimary: planovaOnOrange,
    secondary: planovaOrange,
    onSecondary: planovaOnOrange,
    tertiary: planovaInk,
    surface: Colors.white,
    surfaceTint: Colors.transparent,
  ),
  scaffoldBackgroundColor: Colors.white,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF7F8FA),
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
      backgroundColor: planovaInk,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: planovaInk),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Colors.transparent,
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? planovaOrange
            : planovaInk,
        size: 28,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 12,
        color: states.contains(WidgetState.selected)
            ? planovaOrange
            : planovaInk,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    ),
  ),
);
