import 'package:classync/ui/sign_in_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  Future<void> tapSignIn(
    WidgetTester tester,
    Future<void> Function() signIn,
  ) async {
    await tester.pumpWidget(MaterialApp(home: SignInPage(signIn: signIn)));
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
  }

  bool buttonEnabled(WidgetTester tester) =>
      tester
          .widget<ButtonStyleButton>(find.byWidgetPredicate(
            (w) => w is ButtonStyleButton,
          ))
          .onPressed !=
      null;

  testWidgets('closing the account picker is not an error', (tester) async {
    await tapSignIn(tester, () async {
      throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
    });
    expect(find.byType(SnackBar), findsNothing);
    expect(buttonEnabled(tester), isTrue);
  });

  testWidgets('a Google failure shows a message', (tester) async {
    await tapSignIn(tester, () async {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'bad client',
      );
    });
    expect(find.textContaining('Sign-in failed'), findsOneWidget);
    expect(buttonEnabled(tester), isTrue);
  });

  testWidgets('a Firebase failure shows a message', (tester) async {
    await tapSignIn(tester, () async {
      throw FirebaseAuthException(code: 'network-request-failed');
    });
    expect(find.textContaining('Sign-in failed'), findsOneWidget);
    expect(buttonEnabled(tester), isTrue);
  });
}
