import 'dart:convert';
import 'dart:io';

import 'package:classync/model/routine.dart';
import 'package:classync/ui/grid_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repo.dart';

void main() {
  final routine = Routine.parse(
    jsonDecode(File('test/fixtures/routine.json').readAsStringSync())
        as Map<String, dynamic>,
  ).$1!;

  Future<FakeRepo> pumpGrid(WidgetTester tester, Routine r) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(r);
    await tester.pumpWidget(MaterialApp(home: GridPage(repo: repo)));
    await tester.pump();
    return repo;
  }

  testWidgets('grid shows fixture cells', (tester) async {
    await pumpGrid(tester, routine);
    expect(find.text('DLD Lab'), findsOneWidget);
    expect(find.text('ASD · 140'), findsOneWidget);
    expect(find.text('09:30–10:20'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);
  });

  testWidgets('editing a cell saves it', (tester) async {
    final repo = await pumpGrid(tester, routine);
    await tester.tap(find.text('STAT').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Room'), '305');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.saved!.row('Sun')[2]!.room, '305');
    expect(repo.saved!.row('Sun')[2]!.course, 'STAT');
  });

  testWidgets('clearing a cell saves it empty', (tester) async {
    final repo = await pumpGrid(tester, routine);
    await tester.tap(find.text('STAT').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(repo.saved!.row('Sun')[2], isNull);
  });

  testWidgets('cancel saves nothing', (tester) async {
    final repo = await pumpGrid(tester, routine);
    await tester.tap(find.text('STAT').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
  });

  testWidgets('save needs a course and a room', (tester) async {
    final repo = await pumpGrid(tester, routine);
    await tester.tap(find.text('STAT').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Room'), '  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('empty routine points to settings', (tester) async {
    await pumpGrid(tester, Routine.empty());
    expect(find.textContaining('Settings'), findsOneWidget);
  });
}
