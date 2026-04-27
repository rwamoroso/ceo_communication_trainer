import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_plan/domain/weekly_lesson_packet_engine.dart';
import 'package:ceo_communication_trainer/services/demo/prompt_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeeklyLessonPacketEngine', () {
    test('buildPromptInput includes current week context and excludes unrelated history', () {
      final directPrompt = seededPrompts.firstWhere((prompt) => prompt.id == 'plan-1');
      final brevityPrompt = seededPrompts.firstWhere((prompt) => prompt.id == 'plan-2');
      final presencePrompt = seededPrompts.firstWhere((prompt) => prompt.id == 'plan-3');
      final unrelatedPrompt = seededPrompts.firstWhere(
        (prompt) => prompt.id == 'baseline-summary',
      );

      final plan = TrainingPlan(
        id: 'plan-1',
        userId: 'user-1',
        startDate: DateTime(2026, 4, 1),
        targetEndDate: DateTime(2026, 6, 10),
        status: 'active',
        currentVersion: TrainingPlanVersion(
          id: 'version-1',
          versionNumber: 1,
          source: 'baseline',
          generatedAt: DateTime(2026, 4, 1),
          rationaleText: 'Lead with direct answers before adding more pressure.',
          items: [
            PlanItem(
              id: 'week-2-direct',
              promptId: directPrompt.id,
              weekNumber: 2,
              dayNumber: 1,
              sequenceNumber: 1,
              scheduledFor: DateTime(2026, 4, 8),
              drillType: directPrompt.category.label,
              focusPillars: directPrompt.activePillars,
              difficultyTier: 1,
              targetMetrics: directPrompt.behaviorTargets,
              status: PlanItemStatus.completed,
            ),
            PlanItem(
              id: 'week-2-brevity',
              promptId: brevityPrompt.id,
              weekNumber: 2,
              dayNumber: 2,
              sequenceNumber: 2,
              scheduledFor: DateTime(2026, 4, 9),
              drillType: brevityPrompt.category.label,
              focusPillars: brevityPrompt.activePillars,
              difficultyTier: 1,
              targetMetrics: brevityPrompt.behaviorTargets,
              status: PlanItemStatus.completed,
            ),
            PlanItem(
              id: 'week-3-direct',
              promptId: directPrompt.id,
              weekNumber: 3,
              dayNumber: 1,
              sequenceNumber: 3,
              scheduledFor: DateTime(2026, 4, 15),
              drillType: directPrompt.category.label,
              focusPillars: directPrompt.activePillars,
              difficultyTier: 2,
              targetMetrics: directPrompt.behaviorTargets,
              status: PlanItemStatus.scheduled,
            ),
            PlanItem(
              id: 'week-3-presence',
              promptId: presencePrompt.id,
              weekNumber: 3,
              dayNumber: 2,
              sequenceNumber: 4,
              scheduledFor: DateTime(2026, 4, 16),
              drillType: presencePrompt.category.label,
              focusPillars: presencePrompt.activePillars,
              difficultyTier: 2,
              targetMetrics: presencePrompt.behaviorTargets,
              status: PlanItemStatus.scheduled,
            ),
          ],
        ),
        previousVersions: const [],
      );

      final sessions = [
        _session(
          id: 'prev-1',
          planItemId: 'week-2-direct',
          prompt: directPrompt,
          response: 'Yes, we should prioritize speed and keep the launch narrow.',
          biggestIssue: 'The answer arrived too late.',
          score: 61,
        ),
        _session(
          id: 'prev-2',
          planItemId: 'week-2-brevity',
          prompt: brevityPrompt,
          response: 'Headline first, risk second, ask third.',
          biggestIssue: 'The headline was buried.',
          score: 67,
        ),
        _session(
          id: 'same-topic',
          prompt: directPrompt,
          response: 'My recommendation is to ship the smaller scope this week.',
          biggestIssue: 'The three reasons were uneven.',
          score: 70,
        ),
        _session(
          id: 'unrelated',
          prompt: unrelatedPrompt,
          response: 'This old summary should not be part of the prompt.',
          biggestIssue: 'Too much detail.',
          score: 72,
        ),
      ];

      final input = WeeklyLessonPacketEngine.buildPromptInput(
        weekNumber: 3,
        plan: plan,
        baseline: _baseline(),
        progress: _progress(),
        sessions: sessions,
      );

      final previousWeekHistory = input['previous_week_history'] as List<dynamic>;
      final sameTopicHistory = input['recent_same_topic_history'] as List<dynamic>;
      final serialized = input.toString();

      expect((input['plan'] as Map<String, dynamic>)['week_number'], 3);
      expect(previousWeekHistory, hasLength(2));
      expect(
        sameTopicHistory.any((entry) => entry['session_id'] == 'same-topic'),
        isTrue,
      );
      expect(serialized.contains('This old summary should not be part of the prompt.'), isFalse);
    });

    test('parseImport accepts strict valid JSON payload', () {
      final weekItems = [
        _planItem(id: 'week-3-direct'),
        _planItem(id: 'week-3-presence'),
      ];

      const rawJson = '''
{
  "week_number": 3,
  "weekly_objective": "Lead with the answer and hold executive presence under pressure.",
  "development_summary": "The user still delays the recommendation and over-explains under challenge.",
  "drills": [
    {
      "plan_item_id": "week-3-direct",
      "lesson_title": "Answer first",
      "lesson_body": "State the recommendation in the first sentence.",
      "good_example": "My recommendation is to launch the narrow scope this week.",
      "example_analysis": "It answers immediately and sets up the rationale cleanly.",
      "user_development_focus": "Stop warming up before the answer.",
      "pre_drill_checklist": ["Lead with the answer", "Use three reasons"]
    },
    {
      "plan_item_id": "week-3-presence",
      "lesson_title": "Calm pushback",
      "lesson_body": "Acknowledge the challenge and restate the recommendation.",
      "good_example": "I hear the concern. I still recommend moving now for two reasons.",
      "example_analysis": "It stays calm and keeps ownership.",
      "user_development_focus": "Avoid sounding defensive when challenged.",
      "pre_drill_checklist": ["Lower the temperature", "Restate the recommendation"]
    }
  ]
}
''';

      final parsed = WeeklyLessonPacketEngine.parseImport(
        expectedWeekNumber: 3,
        weekItems: weekItems,
        rawJson: rawJson,
      );

      expect(parsed.weekNumber, 3);
      expect(parsed.drills, hasLength(2));
      expect(parsed.drills.first.planItemId, 'week-3-direct');
      expect(parsed.weeklyObjective, contains('Lead with the answer'));
    });

    test('parseImport rejects missing plan item entries', () {
      final weekItems = [
        _planItem(id: 'week-3-direct'),
        _planItem(id: 'week-3-presence'),
      ];

      const rawJson = '''
{
  "week_number": 3,
  "weekly_objective": "Stay concise.",
  "development_summary": "More structure is needed.",
  "drills": [
    {
      "plan_item_id": "week-3-direct",
      "lesson_title": "Answer first",
      "lesson_body": "State the answer immediately.",
      "good_example": "My recommendation is X.",
      "example_analysis": "It is direct.",
      "user_development_focus": "Stop circling the point.",
      "pre_drill_checklist": ["Answer first"]
    }
  ]
}
''';

      expect(
        () => WeeklyLessonPacketEngine.parseImport(
          expectedWeekNumber: 3,
          weekItems: weekItems,
          rawJson: rawJson,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('missing lesson entries'),
          ),
        ),
      );
    });
  });
}

TrainingSession _session({
  required String id,
  String? planItemId,
  required PromptTemplate prompt,
  required String response,
  required String biggestIssue,
  required double score,
}) {
  return TrainingSession(
    id: id,
    userId: 'user-1',
    prompt: prompt,
    origin: SessionOrigin.dailyPlan,
    status: SessionStatus.completed,
    startedAt: DateTime(2026, 4, 1),
    planItemId: planItemId,
    attempts: [
      SessionAttempt(
        id: '$id-attempt-1',
        attemptNo: 1,
        responseMode: ResponseMode.typed,
        responseText: response,
        durationSeconds: 40,
        wordCount: response.split(' ').length,
        submittedAt: DateTime(2026, 4, 1),
      ),
    ],
    reviews: [
      AttemptReview(
        score: SessionScore(
          overallScore: score,
          pillarScores: const {
            Pillar.clarity: 65,
            Pillar.structure: 62,
            Pillar.brevity: 60,
            Pillar.presence: 58,
            Pillar.strategicFraming: 55,
            Pillar.pressureResponse: 54,
          },
          behaviorMetrics: const BehaviorMetrics(
            directAnswerRate: 0.7,
            blufUsageRate: 0.6,
            cleanThreePointStructureRate: 0.7,
            averageResponseLengthWords: 65,
          ),
        ),
        feedback: SessionFeedback(
          biggestIssue: biggestIssue,
          secondaryIssue: 'Structure was inconsistent.',
          whatWorked: 'The recommendation was credible.',
          topCoachingPoints: const ['Lead sooner', 'Use cleaner structure'],
          improvedExampleAnswer: 'My recommendation is X for three reasons.',
          nextAttemptTarget: 'Lead with the recommendation in the first sentence.',
        ),
      ),
    ],
    completedAt: DateTime(2026, 4, 1),
    bestAttemptNo: 1,
    finalScore: score,
    scoreDelta: 2,
  );
}

PlanItem _planItem({required String id}) {
  return PlanItem(
    id: id,
    promptId: 'plan-1',
    weekNumber: 3,
    dayNumber: 1,
    sequenceNumber: 1,
    scheduledFor: DateTime(2026, 4, 1),
    drillType: 'Direct answer',
    focusPillars: const [Pillar.clarity, Pillar.structure],
    difficultyTier: 2,
    targetMetrics: const {'direct_answer_rate': 0.8},
    status: PlanItemStatus.scheduled,
  );
}

CommunicationBaseline _baseline() {
  return CommunicationBaseline(
    id: 'baseline-1',
    userId: 'user-1',
    completedAt: DateTime(2026, 4, 1),
    overallScore: 61,
    assignedLevel: CommunicationLevel.managerReady,
    readinessScore: 0.63,
    strengthPillars: const [Pillar.clarity, Pillar.structure],
    weakPillars: const [Pillar.brevity, Pillar.presence],
    behaviorSnapshot: const BehaviorMetrics(
      directAnswerRate: 0.7,
      blufUsageRate: 0.6,
      cleanThreePointStructureRate: 0.65,
      averageResponseLengthWords: 70,
    ),
    summaryText: 'The user needs faster recommendations and tighter structure.',
  );
}

ProgressSnapshot _progress() {
  return const ProgressSnapshot(
    currentLevel: CommunicationLevel.managerReady,
    overallScoreEma: 63,
    readinessScore: 0.65,
    currentStreak: 3,
    totalXp: 90,
    weeklyCompletionRate: 0.8,
    coachingAdoptionRate: 0.6,
    difficultyTolerance: 0.55,
    latestRecalibrationState: RecalibrationState.stable,
    pillarScores: {
      Pillar.clarity: 66,
      Pillar.structure: 63,
      Pillar.brevity: 58,
      Pillar.presence: 57,
      Pillar.strategicFraming: 54,
      Pillar.pressureResponse: 53,
    },
    overallTrend: [60, 61, 63],
    pillarHistory: [],
    missedSessions: 0,
  );
}
