import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DynamicProfilePage(
      themeColor: theme.colorScheme.primary,
      onSignOutSuccess: () {
        context.go('/auth/sign-in');
      },
    );
  }
}
