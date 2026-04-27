import 'dart:math';

import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';

class AdaptiveEngine {
  static const _pillarWeights = {
    Pillar.clarity: 0.22,
    Pillar.structure: 0.22,
    Pillar.brevity: 0.16,
    Pillar.presence: 0.14,
    Pillar.strategicFraming: 0.14,
    Pillar.pressureResponse: 0.12,
  };

  static double computeOverallFromPillars(Map<Pillar, double> pillarScores) {
    return _pillarWeights.entries.fold<double>(
      0,
      (sum, entry) => sum + (pillarScores[entry.key] ?? 0) * entry.value,
    );
  }

  static CommunicationLevel assignLevel({
    required Map<Pillar, double> pillarScores,
    required BehaviorMetrics behavior,
    required double overall,
    required RecalibrationState latestState,
  }) {
    final clarity = pillarScores[Pillar.clarity] ?? 0;
    final structure = pillarScores[Pillar.structure] ?? 0;
    final brevity = pillarScores[Pillar.brevity] ?? 0;
    final strategic = pillarScores[Pillar.strategicFraming] ?? 0;
    final pressure = pillarScores[Pillar.pressureResponse] ?? 0;
    final allPillars = pillarScores.values.every((value) => value >= 65);
    final elitePillars = pillarScores.values.every((value) => value >= 80);

    if (overall >= 90 &&
        elitePillars &&
        behavior.blufUsageRate >= 0.85 &&
        latestState != RecalibrationState.regressing) {
      return CommunicationLevel.ceoLevel;
    }
    if (overall >= 80 && allPillars && behavior.directAnswerRate >= 0.75) {
      return CommunicationLevel.executiveReady;
    }
    if (overall >= 70 &&
        clarity >= 65 &&
        structure >= 65 &&
        strategic >= 55 &&
        pressure >= 50) {
      return CommunicationLevel.directorReady;
    }
    if (overall >= 60 && clarity >= 55 && structure >= 55 && brevity >= 45) {
      return CommunicationLevel.managerReady;
    }
    if (overall >= 50 && clarity >= 45 && structure >= 45) {
      return CommunicationLevel.structured;
    }
    if (overall >= 35 && clarity >= 30) {
      return CommunicationLevel.understandable;
    }
    return CommunicationLevel.reactive;
  }

  static double computeReadiness({
    required double normalizedOverall,
    required double consistency,
    required double coachingAdoption,
    required double difficultyTolerance,
  }) {
    return (0.55 * normalizedOverall) +
        (0.25 * consistency) +
        (0.10 * coachingAdoption) +
        (0.10 * difficultyTolerance);
  }

  static RecalibrationState classifyWeeklyState({
    required List<double> recentScores,
    required List<double> previousScores,
    required double weeklyCompletionRate,
    required List<double> weakestPillarHistory,
  }) {
    if (recentScores.isEmpty) {
      return RecalibrationState.stable;
    }

    final recentAverage =
        recentScores.reduce((a, b) => a + b) / recentScores.length;
    final previousAverage = previousScores.isEmpty
        ? recentAverage
        : previousScores.reduce((a, b) => a + b) / previousScores.length;
    final delta = recentAverage - previousAverage;

    final weakestDelta = weakestPillarHistory.length >= 2
        ? weakestPillarHistory.last - weakestPillarHistory.first
        : 0.0;

    if (delta <= -5 || (weeklyCompletionRate < 0.5 && weakestDelta <= -5)) {
      return RecalibrationState.regressing;
    }
    if (delta >= 6 && weeklyCompletionRate >= 0.8 && weakestDelta >= 5) {
      return RecalibrationState.accelerating;
    }
    if (delta >= -2 &&
        delta <= 2 &&
        weeklyCompletionRate >= 0.7 &&
        weakestDelta < 3) {
      return RecalibrationState.plateau;
    }
    return RecalibrationState.stable;
  }

  static TrainingPlan generateInitialPlan({
    required String userId,
    required CommunicationBaseline baseline,
    required UserProfile profile,
    required List<PromptTemplate> promptLibrary,
  }) {
    final weakSet = baseline.weakPillars.toSet();
    final startDate = _startOfToday();
    final items = <PlanItem>[];

    var promptCursor = 0;
    PromptTemplate pickPrompt(PromptCategory category, int difficulty) {
      final matches = promptLibrary
          .where(
            (prompt) =>
                prompt.category == category &&
                prompt.difficultyTier <= difficulty &&
                prompt.difficultyTier >= max(1, difficulty - 1),
          )
          .toList();
      if (matches.isEmpty) {
        return promptLibrary[promptCursor++ % promptLibrary.length];
      }
      final prompt = matches[promptCursor++ % matches.length];
      return prompt;
    }

    final foundationalTrack = <PromptCategory>[
      PromptCategory.directAnswerDiscipline,
      PromptCategory.blufStructuredThinking,
      PromptCategory.listeningSummarization,
      PromptCategory.brevityCompression,
      PromptCategory.executivePresence,
    ];

    for (var week = 1; week <= 10; week++) {
      final tier = min(
        4,
        1 + ((week - 1) ~/ 2) + (baseline.overallScore ~/ 15),
      );
      final weekFocuses = _weekFocuses(week, weakSet);

      for (var day = 1; day <= 5; day++) {
        final category = week <= 2
            ? foundationalTrack[(day - 1) % foundationalTrack.length]
            : weekFocuses[(day - 1) % weekFocuses.length];
        final prompt = pickPrompt(category, tier);
        final date = startDate.add(
          Duration(days: ((week - 1) * 7) + (day - 1)),
        );

        items.add(
          PlanItem(
            id: 'plan-$week-$day-${prompt.id}',
            promptId: prompt.id,
            weekNumber: week,
            dayNumber: day,
            sequenceNumber: items.length + 1,
            scheduledFor: date,
            drillType: prompt.category.label,
            focusPillars: prompt.activePillars,
            difficultyTier: tier,
            targetMetrics: prompt.behaviorTargets,
            status: PlanItemStatus.scheduled,
          ),
        );
      }
    }

    final version = TrainingPlanVersion(
      id: 'plan-version-1',
      versionNumber: 1,
      source: 'baseline',
      generatedAt: DateTime.now(),
      rationaleText:
          'Answer-first fundamentals lead, then the plan expands into pressure and strategic framing once clarity and structure stabilize.',
      items: items,
    );

    return TrainingPlan(
      id: 'plan-$userId',
      userId: userId,
      startDate: startDate,
      targetEndDate: startDate.add(const Duration(days: 69)),
      status: 'active',
      currentVersion: version,
      previousVersions: const [],
    );
  }

  static WeeklyRecalibration generateWeeklyRecalibration({
    required int weekNumber,
    required ProgressSnapshot progress,
    required List<TrainingSession> sessions,
  }) {
    final recentCompleted =
        sessions.where((session) => session.isCompleted).toList()
          ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));

    final recentScores = recentCompleted
        .skip(max(0, recentCompleted.length - 5))
        .map((session) => session.finalScore ?? 0)
        .toList();
    final previousScores = recentCompleted
        .take(max(0, recentCompleted.length - 5))
        .map((session) => session.finalScore ?? 0)
        .toList();
    final weakestPillar = progress.pillarScores.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
    final weakestHistory = progress.pillarHistory
        .where((point) => point.pillar == weakestPillar)
        .map((point) => point.score)
        .toList();

    final classification = classifyWeeklyState(
      recentScores: recentScores,
      previousScores: previousScores,
      weeklyCompletionRate: progress.weeklyCompletionRate,
      weakestPillarHistory: weakestHistory,
    );

    final ruleHits = _ruleHits(progress, weakestPillar, classification);

    final summary = switch (classification) {
      RecalibrationState.accelerating =>
        'The user is improving across multiple pillars, so week ${weekNumber + 1} can add one step more complexity.',
      RecalibrationState.plateau =>
        'Progress has flattened, so the next week reduces novelty and reinforces repeatable structure.',
      RecalibrationState.regressing =>
        'Readiness softened, so the next week returns to answer-first fundamentals and lower difficulty.',
      RecalibrationState.stable =>
        'Steady progress continues, with the next week keeping pressure calibrated while reinforcing weak behaviors.',
    };

    return WeeklyRecalibration(
      id: 'recal-$weekNumber-${DateTime.now().millisecondsSinceEpoch}',
      weekNumber: weekNumber,
      classification: classification,
      ruleHits: ruleHits,
      changesSummary: summary,
      createdAt: DateTime.now(),
    );
  }

  static List<String> _ruleHits(
    ProgressSnapshot progress,
    Pillar weakestPillar,
    RecalibrationState classification,
  ) {
    final hits = <String>[];
    final clarity = progress.pillarScores[Pillar.clarity] ?? 0;
    final structure = progress.pillarScores[Pillar.structure] ?? 0;

    if ((progress.pillarScores[Pillar.structure] ?? 0) < 60) {
      hits.add('low_structure');
    }
    if ((progress.pillarScores[Pillar.brevity] ?? 0) < 58) {
      hits.add('long_response_risk');
    }
    if ((progress.pillarScores[Pillar.presence] ?? 0) < 58) {
      hits.add('presence_support');
    }
    if (weakestPillar == Pillar.clarity || clarity < 60 || structure < 60) {
      hits.add('clarity_before_strategy');
    }
    hits.add(classification.code);
    return hits;
  }

  static List<PromptCategory> _weekFocuses(int week, Set<Pillar> weakPillars) {
    if (week <= 2) {
      return const [
        PromptCategory.directAnswerDiscipline,
        PromptCategory.blufStructuredThinking,
        PromptCategory.brevityCompression,
        PromptCategory.listeningSummarization,
        PromptCategory.executivePresence,
      ];
    }
    if (week <= 4) {
      return const [
        PromptCategory.brevityCompression,
        PromptCategory.executivePresence,
        PromptCategory.blufStructuredThinking,
        PromptCategory.directAnswerDiscipline,
        PromptCategory.pressureResponse,
      ];
    }
    if (week <= 6) {
      return const [
        PromptCategory.pressureResponse,
        PromptCategory.blufStructuredThinking,
        PromptCategory.executivePresence,
        PromptCategory.directAnswerDiscipline,
        PromptCategory.listeningSummarization,
      ];
    }
    if (week <= 8 &&
        !weakPillars.contains(Pillar.clarity) &&
        !weakPillars.contains(Pillar.structure)) {
      return const [
        PromptCategory.strategicFraming,
        PromptCategory.pressureResponse,
        PromptCategory.executivePresence,
        PromptCategory.brevityCompression,
        PromptCategory.directAnswerDiscipline,
      ];
    }
    return const [
      PromptCategory.blufStructuredThinking,
      PromptCategory.directAnswerDiscipline,
      PromptCategory.pressureResponse,
      PromptCategory.executivePresence,
      PromptCategory.brevityCompression,
    ];
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
