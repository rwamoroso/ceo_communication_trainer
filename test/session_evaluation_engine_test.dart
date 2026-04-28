import 'package:ceo_communication_trainer/features/training_session/domain/session_evaluation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseImport accepts manual coaching JSON', () {
    final parsed = SessionEvaluationEngine.parseImport(
      rawJson: '''
{
  "overall_score": 74,
  "pillar_scores": {
    "clarity": 80,
    "structure": 76,
    "brevity": 68,
    "presence": 72,
    "strategic_framing": 70,
    "pressure_response": 65
  },
  "behavior_metrics": {
    "direct_answer_rate": 0.85,
    "bluf_usage_rate": 0.8,
    "clean_three_point_structure_rate": 0.7,
    "average_response_length_words": 78,
    "filler_words_per_minute": null,
    "words_per_minute": null
  },
  "biggest_issue": "Your second point drifted away from the recommendation.",
  "secondary_issue": "The ending did not make the next step explicit.",
  "what_worked": "You answered early and kept the tone direct.",
  "top_coaching_points": [
    "Keep every point tied to the recommendation.",
    "End with the concrete next step.",
    "Trim one sentence from the middle."
  ],
  "improved_example_answer": "My recommendation is to narrow scope this week for three reasons...",
  "next_attempt_target": "State the answer first and end with the owner and next step.",
  "next_day_drill_update": {
    "plan_item_id": "plan-item-2",
    "adjustment_reason": "The user still needs tighter answer-first repetition tomorrow.",
    "user_development_focus": "Keep the opening sentence decisive and reduce setup.",
    "drill_purpose": "Train a cleaner answer-first opening under pressure.",
    "success_signals": [
      "Lead with the answer in the first sentence.",
      "Use no more than three support points.",
      "End with the concrete next step."
    ],
    "pre_drill_checklist": [
      "Lead with the answer",
      "Name the owner"
    ],
    "ai_scenario_context": "The CEO asks for a recommendation during a tense update.",
    "ai_prompt_text": "Give the recommendation immediately and defend it in three short points."
  }
}
''',
    );

    expect(parsed.scoredAttempt.score.overallScore, 74);
    expect(parsed.scoredAttempt.feedback.topCoachingPoints, hasLength(3));
    expect(parsed.scoredAttempt.score.behaviorMetrics.retryCount, 0);
    expect(parsed.nextDayDrillUpdate?.planItemId, 'plan-item-2');
  });

  test('parseImport rejects invalid JSON payloads', () {
    expect(
      () =>
          SessionEvaluationEngine.parseImport(rawJson: '{"overall_score": 74}'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('pillar_scores'),
        ),
      ),
    );
  });
}
