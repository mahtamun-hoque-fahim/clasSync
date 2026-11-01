import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// The Firebase project's web client ID, from google-services.json (client_type 3).
const _serverClientId =
    '902685771964-lf0adn999ru0m4ij0d8b5jl057uuioig.apps.googleusercontent.com';

// The plugin allows initialize to run only once.
Future<void>? _ready;

Future<void> _ensureReady() =>
    _ready ??= GoogleSignIn.instance.initialize(serverClientId: _serverClientId);

/// Web uses a popup. Android uses the native account picker, because the
/// browser redirect flow fails with "missing initial state" on real phones.
Future<void> signInWithGoogle() async {
  if (kIsWeb) {
    await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    return;
  }
  await _ensureReady();
  final account = await GoogleSignIn.instance.authenticate();
  final credential = GoogleAuthProvider.credential(
    idToken: account.authentication.idToken,
  );
  await FirebaseAuth.instance.signInWithCredential(credential);
}

/// Also signs out of the Android picker, so the next sign-in can choose another account.
Future<void> signOutOfGoogle() async {
  await FirebaseAuth.instance.signOut();
  if (kIsWeb) return;
  await _ensureReady();
  await GoogleSignIn.instance.signOut();
}
