import 'package:flutter/material.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_tracker/main.dart';
import 'package:dynamic_backend_bridge/src/providers/core_providers.dart';

class HostingWizardPage extends ConsumerWidget {
  final ConfigService configService;

  const HostingWizardPage({super.key, required this.configService});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: HostingWizard(
          configService: configService,
          onValidate: (AppConfig config) async {
            try {
              final overrides = await initializeBackend(config);
              final container = ProviderContainer(overrides: overrides);
              final auth = container.read(authRepositoryProvider);
              final result = await auth.validateConnection();
              container.dispose();
              return result;
            } catch (e) {
              return e.toString();
            }
          },
          onComplete: (AppConfig config) async {
            final scope = BackendScope.of(context);
            final router = GoRouter.of(context);
            final overrides = await initializeBackend(config);
            final configService = ref.read(configServiceProvider);
            scope.updateOverrides([
              configServiceProvider.overrideWithValue(configService),
              ...overrides,
            ]);
            ref.read(appConfigProvider.notifier).state = config;
            router.go('/auth/sign-in');
          },
        ),
      ),
    );
  }
}
