import 'package:flutter/material.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:task_tracker/firebase_options.dart';
import 'package:task_tracker/main.dart';

class HostingWizardPage extends StatelessWidget {
  final ConfigService configService;

  const HostingWizardPage({
    super.key,
    required this.configService,
  });

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    return Scaffold(
      body: SafeArea(
        child: HostingWizard(
          configService: configService,
          onValidate: (AppConfig config) async {
            try {
              await DynamicBackendBridge.initialize(
                config: config,
                getIt: getIt,
                defaultFirebaseOptions: DefaultFirebaseOptions.currentPlatform,
              );
              setupLocator(); // Refresh repository instances to bind to the new backend
              final auth = getIt<AuthRepository>();
              return await auth.validateConnection();
            } catch (e) {
              return e.toString();
            }
          },
          onComplete: (AppConfig config) {
            configNotifier.value = config;
            setupAuthListener();
            context.go('/auth/sign-in');
          },
        ),
      ),
    );
  }
}
