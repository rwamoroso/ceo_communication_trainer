import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';

abstract class ProfileRepository {
  UserProfile? get currentProfile;

  Future<void> saveProfile({
    required String displayName,
    required String roleTitle,
    required SeniorityBand seniorityBand,
    required String industry,
    required String timezone,
  });

  Future<void> completeOnboarding({
    required int weeklyGoalCount,
    required List<String> communicationContexts,
    required List<String> goals,
    required bool microphoneConsent,
    required ResponseMode preferredResponseMode,
  });
}
