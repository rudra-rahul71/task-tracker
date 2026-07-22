import 'package:task_tracker/features/account/presentation/pages/account.dart';
import 'package:task_tracker/features/auth/presentation/pages/sign_in.dart';
import 'package:task_tracker/features/auth/presentation/pages/hosting_wizard_page.dart';
import 'package:task_tracker/features/home/presentation/pages/home.dart';
import 'package:task_tracker/features/tasks/presentation/pages/tasks.dart';
import 'package:task_tracker/features/trackers/presentation/pages/trackers.dart';
import 'package:task_tracker/core/database/db_service.dart';
import 'package:task_tracker/core/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';
import 'package:task_tracker/core/config/app_environment.dart';
import 'features/splash/presentation/pages/splash.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';

final getIt = GetIt.instance;
final configNotifier = ValueNotifier<AppConfig?>(null);

void setupLocator() {
  if (getIt.isRegistered<TaskRepository>()) {
    getIt.unregister<TaskRepository>();
  }
  if (getIt.isRegistered<TrackerRepository>()) {
    getIt.unregister<TrackerRepository>();
  }
  getIt.registerLazySingleton<TaskRepository>(() => TaskRepository());
  getIt.registerLazySingleton<TrackerRepository>(() => TrackerRepository());
}

void setupAuthListener() {
  if (getIt.isRegistered<AuthRepository>()) {
    getIt<AuthRepository>().authStateChanges.listen((UserEntity? user) async {
      if (user == null) {
        await DatabaseService.instance.clearAllData();
      }
    });
  }
}

Future<void> initializeBackend(AppConfig config) async {
  await DynamicBackendBridge.initialize(
    config: config,
    getIt: getIt,
    defaultSupabaseUrl: AppEnvironment.defaultSupabaseUrl,
    defaultSupabaseAnonKey: AppEnvironment.defaultSupabaseAnonKey,
  );
  setupLocator();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final configService = ConfigService();
  final savedConfig = await configService.getSavedConfig();
  
  setupLocator();

  if (savedConfig != null) {
    try {
      await initializeBackend(savedConfig);
      configNotifier.value = savedConfig;
      setupAuthListener();
    } catch (e) {
      debugPrint('Error initializing saved backend config: $e');
    }
  }

  // Register the global notifier so pages can trigger rebuilds on backend change
  getIt.registerSingleton<ValueNotifier<AppConfig?>>(configNotifier);
  getIt.registerSingleton<ConfigService>(configService);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD4AF37), // Gold seed color
        brightness: Brightness.dark,
        primary: const Color(0xFFD4AF37), // Darker yellow / Gold accent
        onPrimary: Colors.black,
        secondary: const Color(0xFFE5A93C),
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
    );

    return ValueListenableBuilder<AppConfig?>(
      valueListenable: configNotifier,
      builder: (context, config, child) {
        final authStream = getIt.isRegistered<AuthRepository>()
            ? getIt<AuthRepository>().authStateChanges
            : Stream<UserEntity?>.value(null);

        return StreamBuilder<UserEntity?>(
          stream: authStream,
          builder: (context, snapshot) {
            return MaterialApp.router(
              title: 'Task Tracker',
              debugShowCheckedModeBanner: false,
              theme: theme,
              routerConfig: _router,
            );
          },
        );
      },
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final bool hasConfig = getIt.isRegistered<AuthRepository>();
    final String goingTo = state.fullPath ?? '/';

    // 1. If backend isn't configured, force redirect to /hosting-wizard
    if (!hasConfig) {
      if (goingTo != '/hosting-wizard') {
        return '/hosting-wizard';
      }
      return null;
    }

    // 2. If backend is configured, handle standard auth states
    final auth = getIt<AuthRepository>();
    final UserEntity? user = auth.currentUser;
    final bool loggedIn = user != null;

    if (loggedIn) {
      if (goingTo == '/auth/sign-in' || goingTo == '/hosting-wizard') {
        return '/home';
      }
      return null;
    } else {
      if (goingTo != '/' && goingTo != '/auth/sign-in') {
        return '/auth/sign-in';
      }
      return null;
    }
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const SplashPage();
      },
    ),
    GoRoute(
      path: '/hosting-wizard',
      builder: (BuildContext context, GoRouterState state) {
        return HostingWizardPage(
          configService: getIt<ConfigService>(),
        );
      },
    ),
    GoRoute(
      path: '/auth/sign-in',
      builder: (BuildContext context, GoRouterState state) {
        return const SignInPage();
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
        return NavigatorScafold(
          navigationShell: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (BuildContext context, GoRouterState state) {
                return const HomePage();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (BuildContext context, GoRouterState state) {
                return const TasksPage();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trackers',
              builder: (BuildContext context, GoRouterState state) {
                return const TrackersPage();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/account',
              builder: (BuildContext context, GoRouterState state) {
                return const AccountPage();
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
