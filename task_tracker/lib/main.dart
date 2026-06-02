import 'package:task_tracker/firebase_options.dart';
import 'package:task_tracker/features/account/presentation/pages/account.dart';
import 'package:task_tracker/features/auth/presentation/pages/sign_in.dart';
import 'package:task_tracker/features/auth/presentation/pages/verify_email.dart';
import 'package:task_tracker/features/home/presentation/pages/home.dart';
import 'package:task_tracker/features/trackers/presentation/pages/trackers.dart';
import 'package:task_tracker/core/database/db_service.dart';
import 'package:task_tracker/core/widgets/app_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'features/splash/presentation/pages/splash.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Ready to register API/State services in the future
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Graceful error handling if options are placeholders or mock configurations
    debugPrint('Firebase failed to initialize: $e');
  }
  
  setupLocator();

  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user == null) {
      await DatabaseService.instance.clearAllData();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return MaterialApp.router(
          title: 'Task Tracker',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
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
            navigationRailTheme: const NavigationRailThemeData(
              backgroundColor: Color(0xFF1A1A1A),
              selectedIconTheme: IconThemeData(color: Color(0xFFD4AF37)),
              unselectedIconTheme: IconThemeData(color: Colors.grey),
            ),
          ),
          routerConfig: _router,
        );
      },
    );
  }
}

const List<String> publicRoutes = ['/', '/auth/sign-in'];
const String verifyEmailRoute = '/auth/verify-email';

final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = user != null;
    final bool emailVerified = user?.emailVerified ?? false;

    final String goingTo = state.fullPath ?? '/';

    if (loggedIn) {
      if (!emailVerified && goingTo != verifyEmailRoute) {
        return verifyEmailRoute;
      }
      return null;
    } else {
      if (!publicRoutes.contains(goingTo)) {
        return '/auth/sign-in';
      }
      return null;
    }
  },
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        if (state.fullPath == '/' || state.fullPath!.startsWith('/auth')) {
          return child;
        }
        return NavigatorScafold(
          location: state.fullPath,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const SplashPage();
          },
        ),
        GoRoute(
          path: '/auth/sign-in',
          builder: (BuildContext context, GoRouterState state) {
            return const SignInPage();
          },
        ),
        GoRoute(
          path: '/auth/verify-email',
          builder: (BuildContext context, GoRouterState state) {
            return const VerifyEmailPage();
          },
        ),
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) {
            return const HomePage();
          },
        ),
        GoRoute(
          path: '/trackers',
          builder: (BuildContext context, GoRouterState state) {
            return const TrackersPage();
          },
        ),
        GoRoute(
          path: '/account',
          builder: (BuildContext context, GoRouterState state) {
            return const AccountPage();
          },
        ),
      ],
    ),
  ],
);
