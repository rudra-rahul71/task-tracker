import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
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
        final authRepo = GetIt.instance<AuthRepository>();
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
    return Scaffold(
      backgroundColor: Colors.black, // Sleek black backdrop for the premium splash
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/images/logo.png',
            width: 250,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if logo is missing or loading fails
              return const Icon(
                Icons.check_circle_outline,
                size: 120,
                color: Colors.amber,
              );
            },
          ),
        ),
      ),
    );
  }
}
