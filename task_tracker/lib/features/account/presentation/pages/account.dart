import 'package:task_tracker/features/auth/presentation/pages/sign_in.dart';
import 'package:task_tracker/core/database/db_service.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  User? user;

  SignedOutAction _signOut() {
    return SignedOutAction((context) async {
      await DatabaseService.instance.clearAllData();
      setState(() {
        user = FirebaseAuth.instance.currentUser;
      });
      if (context.mounted) {
        context.go('/auth/sign-in');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return user != null
        ? ProfileScreen(
            actions: [_signOut()],
            avatarSize: 80,
          )
        : const SignInPage();
  }
}
