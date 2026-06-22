import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/app/shell/app_shell.dart';
import 'package:ceo_communication_trainer/features/auth/presentation/sign_in_screen.dart';
import 'package:ceo_communication_trainer/features/auth/presentation/update_password_screen.dart';
import 'package:ceo_communication_trainer/features/baseline/presentation/baseline_intro_screen.dart';
import 'package:ceo_communication_trainer/features/baseline/presentation/baseline_summary_screen.dart';
import 'package:ceo_communication_trainer/features/dashboard/presentation/home_dashboard_screen.dart';
import 'package:ceo_communication_trainer/features/onboarding/presentation/goals_contexts_screen.dart';
import 'package:ceo_communication_trainer/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:ceo_communication_trainer/features/profile/presentation/profile_screen.dart';
import 'package:ceo_communication_trainer/features/progress/presentation/progress_screen.dart';
import 'package:ceo_communication_trainer/features/training_plan/presentation/plan_screen.dart';
import 'package:ceo_communication_trainer/features/training_plan/presentation/weekly_lesson_setup_screen.dart';
import 'package:ceo_communication_trainer/features/training_session/presentation/drill_session_screen.dart';
import 'package:ceo_communication_trainer/features/training_session/presentation/session_feedback_screen.dart';
import 'package:ceo_communication_trainer/features/training_session/presentation/session_history_detail_screen.dart';
import 'package:ceo_communication_trainer/features/weekly_review/presentation/weekly_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final service = ref.read(appServiceProvider);

  String? redirect(BuildContext context, GoRouterState state) {
    if (service.isLoading) {
      return null;
    }

    final location = state.matchedLocation;
    final inRecovery = ref.read(isInPasswordRecoveryProvider);

    if (inRecovery) {
      return location == '/update-password' ? null : '/update-password';
    }

    final signedIn = ref.read(currentUserProvider) != null;
    final onboardingComplete =
        ref.read(currentProfileProvider)?.hasCompletedOnboarding ?? false;
    final baselineComplete = ref.read(baselineSummaryProvider) != null;

    if (!signedIn) {
      return location == '/sign-in' ? null : '/sign-in';
    }

    if (!onboardingComplete) {
      if (location == '/onboarding/profile' ||
          location == '/onboarding/goals') {
        return null;
      }
      return '/onboarding/profile';
    }

    if (!baselineComplete) {
      if (location.startsWith('/baseline') ||
          location.startsWith('/session/')) {
        return null;
      }
      return '/baseline/intro';
    }

    if (location.startsWith('/plan-item/')) {
      final planItemId = state.pathParameters['planItemId'];
      final plan = ref.read(currentPlanProvider);
      if (planItemId != null && plan != null) {
        for (final item in plan.currentVersion.items) {
          if (item.id != planItemId) {
            continue;
          }
          final packet = ref.read(
            weeklyLessonPacketByWeekProvider(item.weekNumber),
          );
          if (packet == null) {
            return Uri(
              path: '/plan/week/${item.weekNumber}/setup',
              queryParameters: {'nextPlanItemId': planItemId},
            ).toString();
          }
          break;
        }
      }
    }

    if (location == '/sign-in' ||
        location.startsWith('/onboarding') ||
        location == '/baseline/intro' ||
        location == '/update-password') {
      return '/home';
    }

    return null;
  }

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/sign-in',
    refreshListenable: service,
    redirect: redirect,
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/update-password',
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/goals',
        builder: (context, state) => const GoalsContextsScreen(),
      ),
      GoRoute(
        path: '/baseline/intro',
        builder: (context, state) => const BaselineIntroScreen(),
      ),
      GoRoute(
        path: '/baseline/summary',
        builder: (context, state) => const BaselineSummaryScreen(),
      ),
      GoRoute(
        path: '/baseline/drill/:index',
        builder: (context, state) => DrillSessionScreen.baseline(
          baselineIndex: int.parse(state.pathParameters['index']!),
        ),
      ),
      GoRoute(
        path: '/plan-item/:planItemId/drill',
        builder: (context, state) => DrillSessionScreen.planItem(
          planItemId: state.pathParameters['planItemId']!,
        ),
      ),
      GoRoute(
        path: '/plan/week/:weekNumber/setup',
        builder: (context, state) => WeeklyLessonSetupScreen(
          weekNumber: int.parse(state.pathParameters['weekNumber']!),
          nextPlanItemId: state.uri.queryParameters['nextPlanItemId'],
        ),
      ),
      GoRoute(
        path: '/session/:sessionId/retry',
        builder: (context, state) => DrillSessionScreen.retry(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/session/:sessionId/feedback',
        builder: (context, state) => SessionFeedbackScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/history/:sessionId',
        builder: (context, state) => SessionHistoryDetailScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/weekly-review',
        builder: (context, state) => const WeeklyReviewScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
