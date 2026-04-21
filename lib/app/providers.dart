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

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).currentUser,
);

final currentProfileProvider = Provider<UserProfile?>(
  (ref) => ref.watch(profileRepositoryProvider).currentProfile,
);

final baselineSummaryProvider = Provider<CommunicationBaseline?>(
  (ref) => ref.watch(trainingRepositoryProvider).baselineSummary,
);

final currentPlanProvider = Provider<TrainingPlan?>(
  (ref) => ref.watch(trainingRepositoryProvider).currentPlan,
);

final progressSnapshotProvider = Provider<ProgressSnapshot?>(
  (ref) => ref.watch(progressRepositoryProvider).progress,
);

final dashboardSnapshotProvider = Provider<DashboardSnapshot?>(
  (ref) => ref.watch(progressRepositoryProvider).dashboard,
);

final sessionHistoryProvider = Provider<List<TrainingSession>>(
  (ref) => ref.watch(trainingRepositoryProvider).sessions,
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
  (ref) => ref.watch(trainingRepositoryProvider).promptLibrary,
);

final recalibrationsProvider = Provider<List<WeeklyRecalibration>>(
  (ref) => ref.watch(trainingRepositoryProvider).recalibrations,
);
