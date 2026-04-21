import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/scoring_engine.dart';
import 'package:ceo_communication_trainer/services/demo/prompt_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoringEngine', () {
    test('rewards answer-first structured responses', () {
      final prompt = seededPrompts.firstWhere(
        (item) => item.category == PromptCategory.blufStructuredThinking,
      );

      final result = ScoringEngine.evaluate(
        prompt: prompt,
        responseText:
            'My recommendation is to delay launch by one week. First, the current build will create avoidable rework. Second, the delay protects customer trust. Third, it gives the team time to stabilize the integration. I need approval today.',
        responseMode: ResponseMode.typed,
      );

      expect(result.score.overallScore, greaterThan(70));
      expect(result.score.behaviorMetrics.directAnswerRate, greaterThan(0.7));
      expect(
        result.score.behaviorMetrics.cleanThreePointStructureRate,
        greaterThan(0.7),
      );
    });

    test('flags delayed answers', () {
      final prompt = seededPrompts.firstWhere(
        (item) => item.category == PromptCategory.directAnswerDiscipline,
      );

      final result = ScoringEngine.evaluate(
        prompt: prompt,
        responseText:
            'There are a few things to consider here because this is a complicated decision and there are many stakeholders. We have timing issues, a tight roadmap, and some uncertainty about adoption. I think we should probably pause the launch for now.',
        responseMode: ResponseMode.typed,
      );

      expect(result.score.behaviorMetrics.directAnswerRate, lessThan(0.7));
      expect(result.feedback.biggestIssue, contains('delayed the answer'));
    });
  });
}
