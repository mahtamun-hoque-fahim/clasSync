import 'dart:convert';
import 'dart:io';

import 'package:classync/model/routine.dart';
import 'package:classync/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repo.dart';

void main() {
  final text = File('test/fixtures/routine.json').readAsStringSync();
  final routine = Routine.parse(jsonDecode(text) as Map<String, dynamic>).$1!;

  Future<FakeRepo> pump(WidgetTester tester, Routine r) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(r);
    await tester.pumpWidget(MaterialApp(home: SettingsPage(repo: repo)));
    await tester.pump();
    return repo;
  }

  Future<void> openImport(WidgetTester tester, String json) async {
    await tester.tap(find.text('Import JSON'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Paste JSON here'),
      json,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a swatch saves the accent', (tester) async {
    final repo = await pump(tester, routine);
    await tester.tap(find.byTooltip('teal'));
    await tester.pump();
    expect(repo.saved!.accent, 'teal');
  });

  testWidgets('valid import replaces the routine after confirming',
      (tester) async {
    final repo = await pump(tester, Routine.empty());
    await openImport(tester, text);
    expect(repo.saved, isNull);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(repo.saved!.days, ['Sun', 'Mon', 'Tue', 'Wed']);
  });

  testWidgets('bad import shows the error and saves nothing', (tester) async {
    final repo = await pump(tester, routine);
    await openImport(tester, '{"days": ["Funday"], "periods": []}');
    expect(find.textContaining('Unknown day'), findsOneWidget);
    expect(repo.saved, isNull);
  });

  testWidgets('text that is not JSON shows an error', (tester) async {
    final repo = await pump(tester, routine);
    await openImport(tester, 'not json');
    expect(find.textContaining('not valid JSON'), findsOneWidget);
    expect(repo.saved, isNull);
  });

  testWidgets('removing a day asks first and keeps data valid', (tester) async {
    final repo = await pump(tester, routine);
    await tester.tap(find.widgetWithText(FilterChip, 'Wed'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repo.saved!.days, ['Sun', 'Mon', 'Tue']);
    expect(Routine.parse(repo.saved!.toJson()).$2, isEmpty);
  });

  testWidgets('adding a day saves it', (tester) async {
    final repo = await pump(tester, routine);
    await tester.tap(find.widgetWithText(FilterChip, 'Thu'));
    await tester.pumpAndSettle();
    expect(repo.saved!.days, contains('Thu'));
  });

  testWidgets('adding a period continues after the last one', (tester) async {
    final repo = await pump(tester, routine);
    await tester.tap(find.text('Add period'));
    await tester.pumpAndSettle();
    expect(repo.saved!.periods.last.start, '15:00');
    expect(repo.saved!.periods.last.end, '15:50');
    expect(repo.saved!.row('Sun').length, 7);
  });

  testWidgets('removing a middle period drops that column', (tester) async {
    final repo = await pump(tester, routine);
    await tester.tap(find.byTooltip('Remove period 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repo.saved!.periods.length, 5);
    expect(repo.saved!.row('Sun')[1]!.course, 'STAT');
  });

  testWidgets('export shows the routine as JSON', (tester) async {
    await pump(tester, routine);
    await tester.tap(find.text('Export JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"DLD Lab"'), findsOneWidget);
  });
}
