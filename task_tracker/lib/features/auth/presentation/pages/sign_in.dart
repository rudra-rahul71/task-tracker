import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:task_tracker/core/utils/snackbar.dart';
import 'package:task_tracker/main.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authRepo = GetIt.instance<AuthRepository>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      UserEntity? user;
      if (_isSignUp) {
        user = await authRepo.signUp(email, password);
        if (mounted && user != null) {
          SnackbarService(
            context,
          ).showSuccessSnackbar(message: 'User successfully created!');
        }
      } else {
        user = await authRepo.signIn(email, password);
      }

      if (mounted) {
        if (user != null) {
          context.go('/home');
        } else {
          SnackbarService(context).showErrorSnackbar(
            message: 'Authentication failed. Please verify credentials.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarService(
          context,
        ).showErrorSnackbar(message: 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo
                  Transform.translate(
                    offset: const Offset(0, 16),
                    child: Center(
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        height: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.check_circle_outline,
                            size: 150,
                            color: theme.colorScheme.primary,
                          );
                        },
                      ),
                    ),
                  ),
                  // App Title
                  Text(
                    'TASK TRACKER',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? 'Create your account to get started'
                        : 'Sign in to manage your tasks',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[^@]+@[^@]+\.[^@]+$',
                      ).hasMatch(value.trim())) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : Text(
                            _isSignUp ? 'SIGN UP' : 'SIGN IN',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  // Toggle Mode Link
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Sign Up",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    onPressed: () async {
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
                    icon: const Icon(
                      Icons.settings_backup_restore_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Reset & Reconfigure Backend',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
