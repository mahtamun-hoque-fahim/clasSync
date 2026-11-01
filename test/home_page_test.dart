import 'package:classync/alerts/scheduler.dart';
import 'package:classync/data/ct_repo.dart';
import 'package:classync/data/routine_repo.dart';
import 'package:classync/model/ct.dart';
import 'package:classync/model/routine.dart';
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
}
