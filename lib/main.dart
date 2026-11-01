import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'alerts/build_alerts.dart';
import 'alerts/scheduler.dart';
import 'data/routine_repo.dart';
import 'firebase_options.dart';
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
        return _SignedInApp(key: ValueKey(user.uid), repo: RoutineRepo(user.uid));
      },
    );
  }
}

class _SignedInApp extends StatefulWidget {
  final RoutineRepo repo;

  const _SignedInApp({super.key, required this.repo});

  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  late final Stream<Routine> _routine = widget.repo.watch().asBroadcastStream();
  late final StreamSubscription<Routine> _alerts;

  @override
  void initState() {
    super.initState();
    _alerts = _routine.listen((r) => alertScheduler.reschedule(buildAlerts(r)));
  }

  @override
  void dispose() {
    _alerts.cancel();
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
          home: HomePage(repo: widget.repo),
        );
      },
    );
  }
}
