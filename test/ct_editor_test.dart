import 'package:classync/model/ct.dart';
import 'package:classync/ui/ct_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<CtEdit?> Function() open(WidgetTester tester, {Ct? initial}) {
    CtEdit? result;
    late Future<CtEdit?> pending;
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return () async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              pending = showCtEditor(context, initial: initial);
              pending.then((value) => result = value);
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    };
  }

  testWidgets('new CT starts with the default reminders', (tester) async {
    late CtEdit? edit;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => edit = await showCtEditor(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Course'), 'DLD');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(edit!.ct!.course, 'DLD');
    expect(edit!.ct!.id, '');
    expect(edit!.ct!.remindBefore.toSet(), {1440, 360, 60});
    expect(edit!.ct!.at.isAfter(DateTime.now()), isTrue);
  });

  testWidgets('save needs a course', (tester) async {
    await open(tester)();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('save needs at least one reminder', (tester) async {
    await open(tester)();
    await tester.enterText(find.widgetWithText(TextField, 'Course'), 'DLD');
    await tester.tap(find.widgetWithText(FilterChip, '1 day'));
    await tester.tap(find.widgetWithText(FilterChip, '6 hours'));
    await tester.tap(find.widgetWithText(FilterChip, '1 hour'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pick at least one reminder.'), findsOneWidget);
  });

  testWidgets('save needs a future time', (tester) async {
    final past = Ct(
      id: 'a',
      course: 'DLD',
      at: DateTime(2020, 1, 1, 9, 30),
      remindBefore: const [60],
    );
    await open(tester, initial: past)();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a future date and time.'), findsOneWidget);
  });

  testWidgets('a custom reminder can be added', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late CtEdit? edit;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => edit = await showCtEditor(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Course'), 'DLD');
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Minutes before'), '5');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, '5 min'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(edit!.ct!.remindBefore, contains(5));
  });

  testWidgets('delete asks to remove an existing CT', (tester) async {
    late CtEdit? edit;
    final existing = Ct(
      id: 'a',
      course: 'DLD',
      at: DateTime.now().add(const Duration(days: 1)),
      remindBefore: const [60],
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              edit = await showCtEditor(context, initial: existing),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(edit!.ct, isNull);
  });
}
