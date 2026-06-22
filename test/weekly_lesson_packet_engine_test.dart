import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_plan/domain/weekly_lesson_packet_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parseImport accepts drill purpose and exactly three success signals',
    () {
      final result = WeeklyLessonPacketEngine.parseImport(
        expectedWeekNumber: 1,
        weekItems: [_planItem()],
        rawJson: '''
{
  "week_number": 1,
  "weekly_objective": "Lead with the answer all week.",
  "development_summary": "The user still delays the recommendation.",
  "drills": [
    {
      "plan_item_id": "plan-item-1",
      "lesson_title": "Answer first",
      "lesson_body": "State the recommendation in the first sentence.",
      "good_example": "My recommendation is to narrow scope and launch this week.",
      "example_analysis": "It answers immediately and keeps the structure tight.",
      "user_development_focus": "Stop using a long setup before the recommendation.",
      "pre_drill_checklist": ["Lead with the answer"],
      "drill_purpose": "Train direct answers so the recommendation lands in the opening sentence.",
      "success_signals": [
        "Lead with the answer in the first sentence.",
        "Keep the response to 55-85 words.",
        "Use a simple structure with no more than three supporting points."
      ],
      "ai_scenario_context": "A leader asks whether to prioritize speed or polish.",
      "ai_prompt_text": "Give the recommendation immediately and support it with three short reasons."
    }
  ]
}
''',
      );

      expect(result.drills.single.drillPurpose, contains('direct answers'));
      expect(result.drills.single.successSignals, hasLength(3));
    },
  );

  test(
    'parseImport rejects drill entries without exactly three success signals',
    () {
      expect(
        () => WeeklyLessonPacketEngine.parseImport(
          expectedWeekNumber: 1,
          weekItems: [_planItem()],
          rawJson: '''
{
  "week_number": 1,
  "weekly_objective": "Lead with the answer all week.",
  "development_summary": "The user still delays the recommendation.",
  "drills": [
    {
      "plan_item_id": "plan-item-1",
      "lesson_title": "Answer first",
      "lesson_body": "State the recommendation in the first sentence.",
      "good_example": "My recommendation is to narrow scope and launch this week.",
      "example_analysis": "It answers immediately and keeps the structure tight.",
      "user_development_focus": "Stop using a long setup before the recommendation.",
      "pre_drill_checklist": ["Lead with the answer"],
      "drill_purpose": "Train direct answers so the recommendation lands in the opening sentence.",
      "success_signals": [
        "Lead with the answer in the first sentence.",
        "Keep the response to 55-85 words."
      ]
    }
  ]
}
''',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('exactly 3 success_signals'),
          ),
        ),
      );
    },
  );
}

PlanItem _planItem() {
  return PlanItem(
    id: 'plan-item-1',
    promptId: 'prompt-1',
    weekNumber: 1,
    dayNumber: 1,
    sequenceNumber: 1,
    scheduledFor: DateTime(2026, 4, 21),
    drillType: 'direct_answer_discipline',
    focusPillars: const [Pillar.clarity, Pillar.structure],
    difficultyTier: 1,
    targetMetrics: const {'direct_answer_rate': 0.85},
    status: PlanItemStatus.scheduled,
  );
}
