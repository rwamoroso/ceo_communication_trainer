import 'dart:async';

import 'package:ceo_communication_trainer/app/bootstrap/app_bootstrap.dart';
import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/app/router/app_router.dart';
import 'package:ceo_communication_trainer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = await AppBootstrap.initialize();
    runApp(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const ExecutiveTrainerApp(),
      ),
    );
  }, (error, stack) {
    // AuthException from deep link handling (e.g. expired OTP) is handled by
    // the auth state listener — swallow it here to prevent an unhandled crash.
    if (error is AuthException) return;
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  });
}

class ExecutiveTrainerApp extends ConsumerWidget {
  const ExecutiveTrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CEO-Level Communication Trainer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: router,
    );
  }
}
