import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:dynamic_backend_bridge/src/providers/core_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward().then((onValue) {
      if (mounted) {
        final authRepo = ref.read(authRepositoryProvider);
        final UserEntity? user = authRepo.currentUser;
        if (user != null) {
          context.go('/home');
        } else {
          context.go('/auth/sign-in');
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/images/logo.png',
            width: 250,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if logo is missing or loading fails
              return Icon(
                Icons.check_circle_outline,
                size: 120,
                color: colorScheme.primary,
              );
            },
          ),
        ),
      ),
    );
  }
}
