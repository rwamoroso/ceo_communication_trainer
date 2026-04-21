import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController(text: 'ryanwamoroso@gmail.com');
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final config = ref.read(appConfigProvider);
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
        _emailController.text,
        _passwordController.text,
        isSignUp: _isSignUp,
      );
      if (!mounted) return;

      if (config.useFakeBackend) {
        final profile = ref.read(currentProfileProvider);
        final baseline = ref.read(baselineSummaryProvider);
        if (!(profile?.hasCompletedOnboarding ?? false)) {
          context.go('/onboarding/profile');
        } else if (baseline == null) {
          context.go('/baseline/intro');
        } else {
          context.go('/home');
        }
      }
      // For Supabase, onAuthStateChange triggers navigation automatically.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Train the way executives communicate.',
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Short drills. Immediate coaching. Weekly recalibration.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSignUp ? 'Create account' : 'Sign in',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.useFakeBackend
                          ? 'Demo mode is active. Sign in with any email to run the full training loop locally.'
                          : _isSignUp
                          ? 'Create an account to get started.'
                          : 'Sign in with your email and password.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    if (!config.useFakeBackend) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        onSubmitted: (_) => _submitting ? null : _submit(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(
                        _submitting
                            ? 'Please wait...'
                            : _isSignUp
                            ? 'Create account'
                            : 'Sign in',
                      ),
                    ),
                    if (!config.useFakeBackend) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Sign in'
                              : "Don't have an account? Sign up",
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
