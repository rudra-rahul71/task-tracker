import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/main.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DynamicSignInPage(
      appName: 'TASK TRACKER',
      appIcon: Image.asset(
        'assets/images/app_icon.png',
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.check_circle_outline,
            size: 120,
            color: theme.colorScheme.primary,
          );
        },
      ),
      themeColor: theme.colorScheme.primary,
      onSignInSuccess: () {
        context.go('/home');
      },
      onResetBackend: () async {
        final router = GoRouter.of(context);
        final configService = GetIt.instance<ConfigService>();
        await configService.clearConfig();
        configNotifier.value = null;
        if (GetIt.instance.isRegistered<AuthRepository>()) {
          await GetIt.instance.unregister<AuthRepository>();
        }
        if (GetIt.instance.isRegistered<DatabaseRepository>()) {
          await GetIt.instance.unregister<DatabaseRepository>();
        }
        setupLocator(); // Unregister and reset repositories
        router.go('/hosting-wizard');
      },
    );
  }
}
