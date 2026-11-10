import 'package:classync/alerts/scheduler.dart';
import 'package:classync/data/ct_repo.dart';
import 'package:classync/data/routine_repo.dart';
import 'package:classync/model/ct.dart';
import 'package:classync/model/routine.dart';
import 'package:classync/model/today.dart';
import 'package:classync/theme.dart';
import 'package:classync/ui/grid_page.dart';
import 'package:classync/ui/home_page.dart';
import 'package:classync/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repo.dart';

class FakeCtRepo implements CtRepo {
  @override
  final String uid = 'test';

  @override
  Stream<List<Ct>> watch() => Stream.value(const []);

  @override
  Future<void> save(Ct ct) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeScheduler extends Fake implements AlertScheduler {
  final bool unlocked;

  FakeScheduler({required this.unlocked});

  @override
  Future<bool> unlock() async => unlocked;

  @override
  Future<bool> needsPermissions() async => false;
}

class BrokenRepo extends FakeRepo {
  BrokenRepo() : super(Routine.empty());

  @override
  Stream<Routine> watch() => Stream.error(const InvalidRoutine(['bad doc']));
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    RoutineRepo repo, {
    required bool unlocked,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        repo: repo,
        ctRepo: FakeCtRepo(),
        scheduler: FakeScheduler(unlocked: unlocked),
      ),
    ));
    await tester.pump();
  }

  // Removes HomePage so its one-minute clock timer is cancelled.
  Future<void> finish(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('a locked phone cannot open settings', (tester) async {
    await pump(tester, FakeRepo(Routine.empty()), unlocked: false);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SettingsPage), findsNothing);
    await finish(tester);
  });

  testWidgets('a locked phone cannot open the week grid', (tester) async {
    await pump(tester, FakeRepo(Routine.empty()), unlocked: false);
    await tester.tap(find.byTooltip('Week'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GridPage), findsNothing);
    await finish(tester);
  });

  testWidgets('a locked phone cannot add a CT', (tester) async {
    await pump(tester, FakeRepo(Routine.empty()), unlocked: false);
    await tester.tap(find.text('Add CT'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    await finish(tester);
  });

  testWidgets('an unlocked phone opens settings', (tester) async {
    await pump(tester, FakeRepo(Routine.empty()), unlocked: true);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SettingsPage), findsOneWidget);
    await finish(tester);
  });

  testWidgets('unreadable data shows a message instead of spinning',
      (tester) async {
    await pump(tester, BrokenRepo(), unlocked: true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('could not be read'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the class running right now is filled with the accent',
      (tester) async {
    final now = DateTime.now();
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    // Wide enough to contain the current minute, clamped to the day so the
    // period always starts before it ends.
    final start = now.hour == 0 && now.minute < 30
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(const Duration(minutes: 30));
    final end = now.hour == 23 && now.minute > 30
        ? DateTime(now.year, now.month, now.day, 23, 59)
        : now.add(const Duration(minutes: 30));
    final day = dayName(now);
    final r = Routine(
      accent: 'blue',
      days: [day],
      periods: [Period(hm(start), hm(end)), const Period('00:00', '00:01')],
      teachers: const {},
      cells: {
        day: const [
          ClassCell(course: 'LIVE', teacher: '', room: '101'),
          null,
        ],
      },
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme('blue'),
      home: HomePage(
        repo: FakeRepo(r),
        ctRepo: FakeCtRepo(),
        scheduler: FakeScheduler(unlocked: true),
      ),
    ));
    await tester.pump();

    Color? fill(String text) => tester
        .widget<Material>(
          find.ancestor(of: find.text(text), matching: find.byType(Material))
              .first,
        )
        .color;

    expect(fill('LIVE'), buildTheme('blue').colorScheme.primaryContainer);
    expect(fill('Gap'), Colors.transparent);
    await finish(tester);
  });
}
