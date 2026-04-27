import 'package:ceo_communication_trainer/app/bootstrap/app_config.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/features/auth/domain/auth_repository.dart';
import 'package:ceo_communication_trainer/features/profile/domain/profile_repository.dart';
import 'package:ceo_communication_trainer/features/progress/domain/progress_repository.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/training_repository.dart';
import 'package:ceo_communication_trainer/services/app_service.dart';
import 'package:ceo_communication_trainer/services/demo/in_memory_app_service.dart';
import 'package:ceo_communication_trainer/services/supabase/supabase_app_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool get _isSupabaseInitialized {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final appServiceProvider = ChangeNotifierProvider<AppService>(
  (ref) {
    final config = ref.watch(appConfigProvider);
    if (config.useFakeBackend || !_isSupabaseInitialized) {
      return InMemoryAppService();
    }
    return SupabaseAppService(
      client: Supabase.instance.client,
      config: config,
    );
  },
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(appServiceProvider),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ref.watch(appServiceProvider),
);

final trainingRepositoryProvider = Provider<TrainingRepository>(
  (ref) => ref.watch(appServiceProvider),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ref.watch(appServiceProvider),
);

// All data-reading providers watch appServiceProvider directly.
// Intermediate repository providers (authRepositoryProvider, etc.) return the
// same AppService object reference on every evaluation, so Riverpod's Provider
// considers the value unchanged and never propagates notifyListeners() calls to
// screens that are kept alive in the StatefulShellRoute indexedStack. Watching
// the ChangeNotifierProvider directly ensures every notifyListeners() reaches
// every widget that cares about the data.

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(appServiceProvider).currentUser,
);

final isInPasswordRecoveryProvider = Provider<bool>(
  (ref) => ref.watch(appServiceProvider).isInPasswordRecovery,
);

final currentProfileProvider = Provider<UserProfile?>(
  (ref) => ref.watch(appServiceProvider).currentProfile,
);

final baselineSummaryProvider = Provider<CommunicationBaseline?>(
  (ref) => ref.watch(appServiceProvider).baselineSummary,
);

final currentPlanProvider = Provider<TrainingPlan?>(
  (ref) => ref.watch(appServiceProvider).currentPlan,
);

final weeklyLessonPacketsProvider = Provider<List<WeeklyLessonPacket>>(
  (ref) => ref.watch(appServiceProvider).weeklyLessonPackets,
);

final weeklyLessonPacketByWeekProvider =
    Provider.family<WeeklyLessonPacket?, int>((ref, weekNumber) {
      return ref.watch(appServiceProvider).weeklyLessonPacketForWeek(weekNumber);
    });

final weeklyLessonForPlanItemProvider =
    Provider.family<WeeklyDrillLesson?, String>((ref, planItemId) {
      return ref.watch(appServiceProvider).weeklyLessonForPlanItem(planItemId);
    });

final progressSnapshotProvider = Provider<ProgressSnapshot?>(
  (ref) => ref.watch(appServiceProvider).progress,
);

final dashboardSnapshotProvider = Provider<DashboardSnapshot?>(
  (ref) => ref.watch(appServiceProvider).dashboard,
);

final sessionHistoryProvider = Provider<List<TrainingSession>>(
  (ref) => ref.watch(appServiceProvider).sessions,
);

final sessionByIdProvider = Provider.family<TrainingSession?, String>((
  ref,
  sessionId,
) {
  final sessions = ref.watch(sessionHistoryProvider);
  for (final session in sessions) {
    if (session.id == sessionId) {
      return session;
    }
  }
  return null;
});

final promptLibraryProvider = Provider<List<PromptTemplate>>(
  (ref) => ref.watch(appServiceProvider).promptLibrary,
);

final recalibrationsProvider = Provider<List<WeeklyRecalibration>>(
  (ref) => ref.watch(appServiceProvider).recalibrations,
);
