import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'alerts/build_alerts.dart';
import 'alerts/build_ct_alerts.dart';
import 'alerts/scheduler.dart';
import 'data/ct_repo.dart';
import 'data/routine_repo.dart';
import 'firebase_options.dart';
import 'model/ct.dart';
import 'model/routine.dart';
import 'theme.dart';
import 'ui/home_page.dart';
import 'ui/sign_in_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await alertScheduler.init();
  runApp(const ClasSyncApp());
}

class ClasSyncApp extends StatelessWidget {
  const ClasSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return MaterialApp(
            title: 'ClasSync',
            theme: buildTheme('blue'),
            home: const SignInPage(),
          );
        }
        return _SignedInApp(
          key: ValueKey(user.uid),
          repo: RoutineRepo(user.uid),
          ctRepo: CtRepo(user.uid),
        );
      },
    );
  }
}

class _SignedInApp extends StatefulWidget {
  final RoutineRepo repo;
  final CtRepo ctRepo;

  const _SignedInApp({super.key, required this.repo, required this.ctRepo});

  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  late final Stream<Routine> _routine = widget.repo.watch().asBroadcastStream();
  late final StreamSubscription<Routine> _routineAlerts;
  late final StreamSubscription<List<Ct>> _ctAlerts;
  Routine? _latestRoutine;
  List<Ct>? _latestCts;

  @override
  void initState() {
    super.initState();
    _routineAlerts = _routine.listen((r) {
      _latestRoutine = r;
      _reschedule();
    }, onError: _logError);
    _ctAlerts = widget.ctRepo.watch().listen((cts) {
      _latestCts = cts;
      _reschedule();
    }, onError: _logError);
  }

  void _logError(Object e) => debugPrint('Sync failed: $e');

  // Waits for both lists, because rescheduling replaces every alert.
  void _reschedule() {
    final routine = _latestRoutine;
    final cts = _latestCts;
    if (routine == null || cts == null) return;
    alertScheduler.reschedule(
      buildAlerts(routine),
      buildCtAlerts(cts, DateTime.now()),
    );
  }

  @override
  void dispose() {
    _routineAlerts.cancel();
    _ctAlerts.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Routine>(
      stream: _routine,
      builder: (context, snapshot) {
        final routine = snapshot.data ?? Routine.empty();
        return MaterialApp(
          title: 'ClasSync',
          theme: buildTheme(routine.accent),
          home: HomePage(repo: widget.repo, ctRepo: widget.ctRepo),
        );
      },
    );
  }
}
