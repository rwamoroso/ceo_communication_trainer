import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';

abstract class TrainingRepository {
  List<PromptTemplate> get promptLibrary;
  List<PromptTemplate> get baselinePrompts;
  TrainingPlan? get currentPlan;
  CommunicationBaseline? get baselineSummary;
  List<TrainingSession> get sessions;
  List<WeeklyRecalibration> get recalibrations;
  List<WeeklyLessonPacket> get weeklyLessonPackets;

  WeeklyLessonPacket? weeklyLessonPacketForWeek(int weekNumber);

  WeeklyDrillLesson? weeklyLessonForPlanItem(String planItemId);

  Future<TrainingSession> openBaselineSession(int index);

  Future<TrainingSession> openPlanSession(String planItemId);

  Future<TrainingSession> openRetrySession(String sessionId);

  Future<TrainingSession> submitAttempt({
    required String sessionId,
    required String responseText,
    required ResponseMode responseMode,
  });

  Future<void> finalizeSession(String sessionId);

  Future<WeeklyRecalibration> generateWeeklyRecalibration();

  Future<String> buildWeeklyLessonPrompt(int weekNumber);

  Future<WeeklyLessonPacket> importWeeklyLessonPacket({
    required int weekNumber,
    required String rawJson,
  });
}
