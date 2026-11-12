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

/// The fill for anything the accent owns - the Now card, the live row, the
/// week-grid cells: the raw swatch the user picked, fully saturated, in both
/// themes. Material's containers are pale washes and never appear here.
Color accentFill(String accent) => swatches[accent] ?? swatches['blue']!;

/// Ink that stays readable on any accent fill: dark on light accents (orange),
/// white on everything else.
Color inkOnAccent(Color fill) =>
    fill.computeLuminance() > 0.4 ? Colors.black : Colors.white;

/// Gradient for the live state, straight from the user's reference formula:
/// top stop = the accent at 70% alpha composited over the surface it sits on,
/// bottom stop = the full accent. Same positions for every swatch; the two
/// shades derive from the theme. Nothing is washed toward white beyond what
/// the formula itself does, and no pale container tone enters.
LinearGradient liveGradient(String accent, Color base) {
  final a = accentFill(accent);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.alphaBlend(a.withValues(alpha: 0.7), base),
      a,
    ],
  );
}

/// Maps the stored preference ("system", "light" or "dark") to a mode.
ThemeMode resolveThemeMode(String value) => switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

ThemeData buildTheme(String accent, {bool dark = false}) {
  final seed = swatches[accent] ?? swatches['blue']!;
  final small = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final big = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    ),
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
