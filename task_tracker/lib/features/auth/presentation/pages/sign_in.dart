import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/main.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onSignInSuccess: () {
        context.go('/home');
      },
      onResetBackend: () async {
        final router = GoRouter.of(context);
        final scope = BackendScope.of(context);
        final configService = ref.read(configServiceProvider);
        await configService.clearConfig();
        ref.read(appConfigProvider.notifier).state = null;
        scope.updateOverrides([
          configServiceProvider.overrideWithValue(configService),
        ]);
        router.go('/hosting-wizard');
      },
    );
  }
}
