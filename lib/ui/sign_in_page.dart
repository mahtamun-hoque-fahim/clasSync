import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/google_auth.dart';

class SignInPage extends StatefulWidget {
  final Future<void> Function() signIn;

  const SignInPage({super.key, this.signIn = signInWithGoogle});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _busy = false;

  void _showFailure(String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign-in failed: $reason')),
    );
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await widget.signIn();
    } on GoogleSignInException catch (e) {
      // Closing the account picker is not a failure.
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showFailure(e.description ?? e.code.name);
      }
    } on FirebaseAuthException catch (e) {
      _showFailure(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ClasSync', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
