import 'package:classync/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default swatch is blue', () {
    expect(swatches.keys.first, 'blue');
  });

  test('offers the seven preset swatches', () {
    expect(swatches.keys, [
      'blue',
      'indigo',
      'teal',
      'green',
      'orange',
      'pink',
      'purple',
    ]);
  });

  test('unknown accent falls back to blue', () {
    expect(buildTheme('nope').colorScheme, buildTheme('blue').colorScheme);
  });

  test('different accents give different colors', () {
    expect(
      buildTheme('teal').colorScheme.primary,
      isNot(buildTheme('blue').colorScheme.primary),
    );
  });

  test('tough color is not a swatch', () {
    expect(swatches.values, isNot(contains(toughColor)));
  });

  test('cards are rounded', () {
    final shape = buildTheme('blue').cardTheme.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(16));
  });

  test('inputs are rounded', () {
    final border =
        buildTheme('blue').inputDecorationTheme.border as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(12));
  });
}
