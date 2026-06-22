import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_plan/presentation/plan_screen.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/training_repository.dart';
import 'package:ceo_communication_trainer/features/training_session/presentation/drill_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan screen shows AI setup needed when week packet is missing', (
    WidgetTester tester,
  ) async {
    final plan = _plan();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentPlanProvider.overrideWithValue(plan),
          weeklyLessonPacketByWeekProvider.overrideWith((ref, weekNumber) {
            return null;
          }),
        ],
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question pack needed'), findsWidgets);
    expect(find.text('Set up AI question pack'), findsWidgets);
  });

  testWidgets('weekly drill shows lesson prep before response composer', (
    WidgetTester tester,
  ) async {
    final plan = _plan();
    final session = TrainingSession(
      id: 'session-1',
      userId: 'user-1',
      prompt: _prompt(),
      origin: SessionOrigin.dailyPlan,
      status: SessionStatus.inProgress,
      startedAt: DateTime(2026, 4, 23),
      planItemId: 'plan-item-1',
      attempts: const [],
      reviews: const [],
    );
    final packet = WeeklyLessonPacket(
      id: 'packet-1',
      planVersionId: plan.currentVersion.id,
      weekNumber: 1,
      weeklyObjective: 'Lead with the recommendation and keep the logic crisp.',
      developmentSummary:
          'Recent answers bury the recommendation and lose structure under pressure.',
      rawImportText: '{"week_number":1}',
      drills: const [
        WeeklyDrillLesson(
          planItemId: 'plan-item-1',
          lessonTitle: 'Answer first',
          lessonBody: 'State the recommendation in the first sentence.',
          goodExample:
              'My recommendation is to narrow scope and launch this week.',
          exampleAnalysis:
              'It answers immediately and keeps the structure tight.',
          userDevelopmentFocus:
              'Stop using a long setup before the recommendation.',
          drillPurpose:
              'Train direct answers so the recommendation lands in the opening sentence.',
          successSignals: [
            'Lead with the answer in the first sentence.',
            'Keep the response to 55-85 words.',
            'Use a simple structure with no more than three supporting points.',
          ],
          preDrillChecklist: ['Lead with the answer', 'Use three reasons'],
        ),
      ],
      createdAt: DateTime(2026, 4, 23),
      updatedAt: DateTime(2026, 4, 23),
    );
    final repository = _FakeTrainingRepository(
      currentPlan: plan,
      weeklyLessonPackets: [packet],
      sessions: [session],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingRepositoryProvider.overrideWithValue(repository),
          currentPlanProvider.overrideWithValue(plan),
          sessionHistoryProvider.overrideWithValue([session]),
          weeklyLessonPacketByWeekProvider.overrideWith((ref, weekNumber) {
            return weekNumber == packet.weekNumber ? packet : null;
          }),
          weeklyLessonForPlanItemProvider.overrideWith((ref, planItemId) {
            return planItemId == 'plan-item-1' ? packet.drills.first : null;
          }),
        ],
        child: MaterialApp(
          home: DrillSessionScreen.planItem(planItemId: 'plan-item-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly drill prep'), findsOneWidget);
    expect(find.text('Answer first'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Drill purpose'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Drill purpose'), findsOneWidget);
    expect(
      find.text(
        'Train direct answers so the recommendation lands in the opening sentence.',
      ),
      findsOneWidget,
    );
    expect(find.text('Success signals'), findsOneWidget);
    expect(find.text('Response draft'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Continue to drill'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Continue to drill'));
    await tester.pumpAndSettle();

    expect(find.text('Response draft'), findsOneWidget);
    expect(find.text('Submit response'), findsOneWidget);
    expect(find.text('Drill purpose'), findsOneWidget);
    expect(find.text('Success signals'), findsOneWidget);
  });

  testWidgets('submitted drills require AI coaching before another step', (
    WidgetTester tester,
  ) async {
    final plan = _plan();
    final packet = WeeklyLessonPacket(
      id: 'packet-1',
      planVersionId: plan.currentVersion.id,
      weekNumber: 1,
      weeklyObjective: 'Lead with the recommendation and keep the logic crisp.',
      developmentSummary:
          'Recent answers bury the recommendation and lose structure under pressure.',
      rawImportText: '{"week_number":1}',
      drills: const [
        WeeklyDrillLesson(
          planItemId: 'plan-item-1',
          lessonTitle: 'Answer first',
          lessonBody: 'State the recommendation in the first sentence.',
          goodExample:
              'My recommendation is to narrow scope and launch this week.',
          exampleAnalysis:
              'It answers immediately and keeps the structure tight.',
          userDevelopmentFocus:
              'Stop using a long setup before the recommendation.',
          drillPurpose:
              'Train direct answers so the recommendation lands in the opening sentence.',
          successSignals: [
            'Lead with the answer in the first sentence.',
            'Keep the response to 55-85 words.',
            'Use a simple structure with no more than three supporting points.',
          ],
          preDrillChecklist: ['Lead with the answer', 'Use three reasons'],
        ),
      ],
      createdAt: DateTime(2026, 4, 23),
      updatedAt: DateTime(2026, 4, 23),
    );
    final session = TrainingSession(
      id: 'session-1',
      userId: 'user-1',
      prompt: _prompt(),
      origin: SessionOrigin.dailyPlan,
      status: SessionStatus.inProgress,
      startedAt: DateTime(2026, 4, 23),
      planItemId: 'plan-item-1',
      attempts: [
        SessionAttempt(
          id: 'attempt-1',
          attemptNo: 1,
          responseMode: ResponseMode.typed,
          responseText:
              'My recommendation is to narrow scope this week so we protect quality, reduce rework, and keep leadership trust intact.',
          durationSeconds: 40,
          wordCount: 18,
          submittedAt: DateTime(2026, 4, 23),
        ),
      ],
      reviews: const [],
    );
    final repository = _FakeTrainingRepository(
      currentPlan: plan,
      weeklyLessonPackets: [packet],
      sessions: [session],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingRepositoryProvider.overrideWithValue(repository),
          currentPlanProvider.overrideWithValue(plan),
          sessionHistoryProvider.overrideWithValue([session]),
          weeklyLessonPacketByWeekProvider.overrideWith((ref, weekNumber) {
            return weekNumber == packet.weekNumber ? packet : null;
          }),
          weeklyLessonForPlanItemProvider.overrideWith((ref, planItemId) {
            return planItemId == 'plan-item-1' ? packet.drills.first : null;
          }),
        ],
        child: MaterialApp(
          home: DrillSessionScreen.planItem(planItemId: 'plan-item-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('AI coaching is required before the next step.'),
      findsOneWidget,
    );
    expect(find.text('Open feedback'), findsOneWidget);
    expect(find.text('Response draft'), findsNothing);
    expect(find.text('Submit response'), findsNothing);
  });
}

class _FakeTrainingRepository implements TrainingRepository {
  _FakeTrainingRepository({
    required this.currentPlan,
    required List<WeeklyLessonPacket> weeklyLessonPackets,
    required List<TrainingSession> sessions,
  }) : _weeklyLessonPackets = weeklyLessonPackets,
       _sessions = sessions;

  @override
  final TrainingPlan? currentPlan;
  final List<WeeklyLessonPacket> _weeklyLessonPackets;
  final List<TrainingSession> _sessions;

  @override
  CommunicationBaseline? get baselineSummary => null;

  @override
  List<PromptTemplate> get baselinePrompts => const [];

  @override
  List<PromptTemplate> get promptLibrary => [_prompt()];

  @override
  List<WeeklyRecalibration> get recalibrations => const [];

  @override
  List<TrainingSession> get sessions => _sessions;

  @override
  List<WeeklyLessonPacket> get weeklyLessonPackets => _weeklyLessonPackets;

  @override
  Future<String> buildWeeklyLessonPrompt(int weekNumber) async => 'prompt';

  @override
  Future<String> buildSessionEvaluationPrompt(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<void> finalizeSession(String sessionId) async {}

  @override
  Future<WeeklyRecalibration> generateWeeklyRecalibration() {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyLessonPacket> generateWeeklyLessonPacket(int weekNumber) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> importSessionEvaluation({
    required String sessionId,
    required String rawJson,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyLessonPacket> importWeeklyLessonPacket({
    required int weekNumber,
    required String rawJson,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> openBaselineSession(int index) {
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> openPlanSession(String planItemId) async {
    return _sessions.first;
  }

  @override
  Future<TrainingSession> openRetrySession(String sessionId) async {
    return _sessions.firstWhere((session) => session.id == sessionId);
  }

  @override
  Future<TrainingSession> submitAttempt({
    required String sessionId,
    required String responseText,
    required ResponseMode responseMode,
  }) {
    throw UnimplementedError();
  }

  @override
  WeeklyLessonPacket? weeklyLessonPacketForWeek(int weekNumber) {
    for (final packet in _weeklyLessonPackets) {
      if (packet.weekNumber == weekNumber) {
        return packet;
      }
    }
    return null;
  }

  @override
  WeeklyDrillLesson? weeklyLessonForPlanItem(String planItemId) {
    for (final packet in _weeklyLessonPackets) {
      final lesson = packet.lessonForPlanItem(planItemId);
      if (lesson != null) {
        return lesson;
      }
    }
    return null;
  }
}

TrainingPlan _plan() {
  return TrainingPlan(
    id: 'plan-1',
    userId: 'user-1',
    startDate: DateTime(2026, 4, 21),
    targetEndDate: DateTime(2026, 6, 30),
    status: 'active',
    currentVersion: TrainingPlanVersion(
      id: 'version-1',
      versionNumber: 1,
      source: 'baseline',
      generatedAt: DateTime(2026, 4, 21),
      rationaleText: 'Build clarity before pressure.',
      items: [
        PlanItem(
          id: 'plan-item-1',
          promptId: _prompt().id,
          weekNumber: 1,
          dayNumber: 1,
          sequenceNumber: 1,
          scheduledFor: DateTime(2026, 4, 21),
          drillType: _prompt().category.label,
          focusPillars: _prompt().activePillars,
          difficultyTier: 1,
          targetMetrics: _prompt().behaviorTargets,
          status: PlanItemStatus.scheduled,
        ),
      ],
    ),
    previousVersions: const [],
  );
}

PromptTemplate _prompt() {
  return const PromptTemplate(
    id: 'plan-1',
    slug: 'plan-1',
    title: 'Recommendation with three reasons',
    category: PromptCategory.directAnswerDiscipline,
    difficultyTier: 1,
    scenarioContext: 'A leader asks whether to prioritize speed or polish.',
    promptText:
        'Give the recommendation immediately and support it with three short reasons.',
    targetDurationSec: 40,
    targetWordRangeMin: 55,
    targetWordRangeMax: 85,
    pillarWeights: {
      Pillar.clarity: 0.45,
      Pillar.structure: 0.3,
      Pillar.brevity: 0.25,
    },
    behaviorTargets: {'direct_answer_rate': 0.85},
  );
}
