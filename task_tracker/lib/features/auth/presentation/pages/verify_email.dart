import 'package:task_tracker/core/database/db_service.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  static AuthCancelledAction _cancel() {
    return AuthCancelledAction((context) {
      FirebaseUIAuth.signOut(context: context).then((value) async {
        await DatabaseService.instance.clearAllData();
        if (context.mounted) {
          context.pop();
        }
      });
    });
  }

  static EmailVerifiedAction _verified(BuildContext context) {
    return EmailVerifiedAction(() {
      context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return EmailVerificationScreen(actions: [_cancel(), _verified(context)]);
  }
}
