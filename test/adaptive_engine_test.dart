import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_plan/domain/adaptive_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveEngine', () {
    test('assigns manager-ready when clarity and structure are solid', () {
      final level = AdaptiveEngine.assignLevel(
        pillarScores: const {
          Pillar.clarity: 62,
          Pillar.structure: 61,
          Pillar.brevity: 52,
          Pillar.presence: 58,
          Pillar.strategicFraming: 49,
          Pillar.pressureResponse: 46,
        },
        behavior: const BehaviorMetrics(
          directAnswerRate: 0.82,
          blufUsageRate: 0.72,
          cleanThreePointStructureRate: 0.8,
          averageResponseLengthWords: 72,
        ),
        overall: 64,
        latestState: RecalibrationState.stable,
      );

      expect(level, CommunicationLevel.managerReady);
    });

    test('classifies plateau when scores flatten despite completion', () {
      final state = AdaptiveEngine.classifyWeeklyState(
        recentScores: const [62, 63, 61, 62, 63],
        previousScores: const [62, 61, 63, 62, 62],
        weeklyCompletionRate: 0.8,
        weakestPillarHistory: const [48, 49],
      );

      expect(state, RecalibrationState.plateau);
    });
  });
}
