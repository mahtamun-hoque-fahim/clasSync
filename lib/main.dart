import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'alerts/alert_sync.dart';
import 'alerts/scheduler.dart';
import 'data/ct_repo.dart';
import 'data/google_auth.dart';
import 'data/routine_repo.dart';
import 'firebase_options.dart';
import 'model/ct.dart';
import 'model/routine.dart';
import 'theme.dart';
import 'ui/home_page.dart';
import 'ui/sign_in_page.dart';
import 'widget/widget_sync.dart';

/// MaterialApp shared by both branches so the theme setup lives in one place.
class ClasSyncMaterialApp extends StatelessWidget {
  final String accent;
  final String themeMode;
  final Widget home;

  const ClasSyncMaterialApp({
    super.key,
    required this.accent,
    required this.themeMode,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClasSync',
      theme: buildTheme(accent),
      darkTheme: buildTheme(accent, dark: true),
      themeMode: resolveThemeMode(themeMode),
      home: home,
    );
  }
}

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
          // No routine is readable while signed out, so follow the system.
          return const ClasSyncMaterialApp(
            accent: 'blue',
            themeMode: 'system',
            home: SignInPage(),
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
  AlertSync? _sync;
  // Returning from Android settings may have granted exact alarms, which only
  // apply to alerts scheduled afterwards.
  late final _lifecycle = AppLifecycleListener(onResume: _refresh);

  void _refresh() => _sync?.refresh();

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // Both the alert schedule and the widget snapshot need routine + items;
    // the widget push happens after every change (fire and forget).
    final sync = _sync = AlertSync(
      alertScheduler.reschedule,
      onSynced: (r, cts) => WidgetSync.push(r, cts),
    );
    _routineAlerts = _routine.listen((r) => sync.routine = r, onError: _logError);
    _ctAlerts = widget.ctRepo.watch().listen(
      (cts) => sync.cts = cts,
      onError: _logError,
    );
  }

  void _logError(Object e) => debugPrint('Sync failed: $e');

  Future<void> _signOut() async {
    await alertScheduler.clear();
    await WidgetSync.clear();
    await signOutOfGoogle();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
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
        return ClasSyncMaterialApp(
          accent: routine.accent,
          themeMode: routine.themeMode,
          home: HomePage(
            repo: widget.repo,
            ctRepo: widget.ctRepo,
            onSignOut: _signOut,
          ),
        );
      },
    );
  }
}
