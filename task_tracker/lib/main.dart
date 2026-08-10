import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';

import 'package:task_tracker/features/account/presentation/pages/account.dart';
import 'package:task_tracker/features/auth/presentation/pages/sign_in.dart';
import 'package:task_tracker/features/auth/presentation/pages/hosting_wizard_page.dart';
import 'package:task_tracker/features/home/presentation/pages/home.dart';
import 'package:task_tracker/features/tasks/presentation/pages/tasks.dart';
import 'package:task_tracker/features/trackers/presentation/pages/trackers.dart';
import 'package:task_tracker/core/database/db_service.dart';
import 'package:task_tracker/core/widgets/app_shell.dart';
import 'package:task_tracker/features/tasks/data/repositories/task_repository.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';
import 'package:task_tracker/core/config/app_environment.dart';
import 'features/splash/presentation/pages/splash.dart';
import 'firebase_options.dart';

final taskRepositoryProvider = Provider((ref) => TaskRepository(
      ref.watch(databaseRepositoryProvider),
      ref.watch(notificationServiceProvider),
    ));
final trackerRepositoryProvider = Provider((ref) => TrackerRepository(ref.watch(databaseRepositoryProvider)));
final configServiceProvider = Provider((ref) => ConfigService());
final appConfigProvider = StateProvider<AppConfig?>((ref) => null);

Future<List<Override>> initializeBackend(AppConfig config) async {
  return DynamicBackendBridge.initialize(
    config: config,
    defaultSupabaseUrl: AppEnvironment.defaultSupabaseUrl,
    defaultSupabaseAnonKey: AppEnvironment.defaultSupabaseAnonKey,
    dbSchema: 'task_tracker',
    defaultNotificationChannelId: 'task_tracker',
    defaultNotificationChannelName: 'Task Tracker Notifications',
    defaultNotificationChannelDesc: 'Notifications for tasks and trackers',
    enableRemoteNotifications: true,
    appId: 'task_tracker',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error (likely missing config): $e');
  }

  final configService = ConfigService();
  final savedConfig = await configService.getSavedConfig();

  List<Override> initialOverrides = [
    configServiceProvider.overrideWithValue(configService),
  ];

  if (savedConfig != null) {
    try {
      final backendOverrides = await initializeBackend(savedConfig);
      initialOverrides.addAll(backendOverrides);
    } catch (e) {
      debugPrint('Error initializing saved backend config: $e');
    }
  }


  runApp(
    BackendScope(
      initialOverrides: initialOverrides,
      child: MyApp(initialConfig: savedConfig),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: AppBannerService.navigatorKey,
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      bool hasConfig = false;
      try {
        ref.read(authRepositoryProvider);
        hasConfig = true;
      } catch (_) {}

      final String goingTo = state.fullPath ?? '/';

      if (!hasConfig) {
        if (goingTo != '/hosting-wizard') {
          return '/hosting-wizard';
        }
        return null;
      }

      final auth = ref.read(authRepositoryProvider);
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
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/hosting-wizard',
        builder: (context, state) => HostingWizardPage(
          configService: ref.read(configServiceProvider),
        ),
      ),
      GoRoute(
        path: '/auth/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigatorScafold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trackers',
                builder: (context, state) => const TrackersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class MyApp extends ConsumerStatefulWidget {
  final AppConfig? initialConfig;
  const MyApp({super.key, this.initialConfig});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialConfig != null) {
        ref.read(appConfigProvider.notifier).state = widget.initialConfig;
      }
      _setupAuthListener();
    });
  }

  void _setupAuthListener() {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      authRepo.authStateChanges.listen((UserEntity? user) async {
        if (user == null) {
          await DatabaseService.instance.clearAllData();
        }
      });
    } catch (_) {
      // Backend not initialized yet
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build(
      primarySeed: const Color(0xFFD4AF37),
      primary: const Color(0xFFD4AF37),
      onPrimary: Colors.black,
      secondary: const Color(0xFFE5A93C),
      tertiary: const Color(0xFF26A69A),
      onTertiary: Colors.black,
      error: const Color(0xFFEF5350),
      onError: Colors.white,
      surface: const Color(0xFF1E1E1E),
      onSurface: Colors.white,
      scaffoldBackgroundColor: const Color(0xFF121212),
    );

    // Watch auth changes so the router can rebuild its redirect logic if needed
    // The redirect logic itself checks auth syncronously.
    try {
      ref.watch(currentUserProvider);
    } catch (_) {}

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Task Tracker',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
  }
}

class BackendScope extends StatefulWidget {
  final Widget child;
  final List<Override> initialOverrides;
  const BackendScope({
    super.key,
    required this.child,
    required this.initialOverrides,
  });

  static BackendScopeState of(BuildContext context) {
    return context.findAncestorStateOfType<BackendScopeState>()!;
  }

  @override
  State<BackendScope> createState() => BackendScopeState();
}

class BackendScopeState extends State<BackendScope> {
  late List<Override> _overrides;
  Key _scopeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _overrides = widget.initialOverrides;
  }

  void updateOverrides(List<Override> newOverrides) {
    setState(() {
      _overrides = newOverrides;
      _scopeKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: _scopeKey,
      overrides: _overrides,
      child: widget.child,
    );
  }
}
