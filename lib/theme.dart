import 'package:flutter/material.dart';

const Map<String, Color> swatches = {
  'blue': Color(0xFF1976D2),
  'indigo': Color(0xFF3F51B5),
  'teal': Color(0xFF009688),
  'green': Color(0xFF388E3C),
  'orange': Color(0xFFFF9800),
  'pink': Color(0xFFE91E63),
  'purple': Color(0xFF7B1FA2),
};

/// Marks tough periods. Kept apart from [swatches] so it reads the same on any accent.
const Color toughColor = Color(0xFFFFB74D);

ThemeData buildTheme(String accent) {
  final seed = swatches[accent] ?? swatches['blue']!;
  final small = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final big = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    cardTheme: CardThemeData(shape: big, elevation: 1),
    dialogTheme: DialogThemeData(shape: big),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: small),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: small),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: small),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: small),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(shape: small),
  );
}
