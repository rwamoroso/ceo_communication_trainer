import 'dart:convert';

import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';

class ValidatedWeeklyLessonPacketImport {
  const ValidatedWeeklyLessonPacketImport({
    required this.weekNumber,
    required this.weeklyObjective,
    required this.developmentSummary,
    required this.rawImportText,
    required this.drills,
    this.previousWeekAnalysis = '',
    this.previousWeekEvaluations = const [],
  });

  final int weekNumber;
  final String weeklyObjective;
  final String developmentSummary;
  final String rawImportText;
  final List<WeeklyDrillLesson> drills;
  final String previousWeekAnalysis;
  final List<WeeklySessionEvaluation> previousWeekEvaluations;

  Map<String, dynamic> toPayload() {
    return {
      'week_number': weekNumber,
      'weekly_objective': weeklyObjective,
      'development_summary': developmentSummary,
      'previous_week_analysis': previousWeekAnalysis,
      'previous_week_evaluations': [
        for (final e in previousWeekEvaluations)
          {
            'session_id': e.sessionId,
            'ai_score': e.aiScore,
            'key_observations': e.keyObservations,
          },
      ],
      'drills': [
        for (final drill in drills)
          {
            'plan_item_id': drill.planItemId,
            'lesson_title': drill.lessonTitle,
            'lesson_body': drill.lessonBody,
            'good_example': drill.goodExample,
            'example_analysis': drill.exampleAnalysis,
            'user_development_focus': drill.userDevelopmentFocus,
            'pre_drill_checklist': drill.preDrillChecklist,
            'drill_purpose': drill.drillPurpose,
            'success_signals': drill.successSignals,
            if (drill.aiScenarioContext != null)
              'ai_scenario_context': drill.aiScenarioContext,
            if (drill.aiPromptText != null)
              'ai_prompt_text': drill.aiPromptText,
          },
      ],
    };
  }
}

class WeeklyLessonPacketEngine {
  static const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

  static String buildPrompt({
    required int weekNumber,
    required TrainingPlan plan,
    required CommunicationBaseline baseline,
    ProgressSnapshot? progress,
    required List<TrainingSession> sessions,
    WeeklyLessonPacket? previousWeekPacket,
  }) {
    final input = buildPromptInput(
      weekNumber: weekNumber,
      plan: plan,
      baseline: baseline,
      progress: progress,
      sessions: sessions,
      previousWeekPacket: previousWeekPacket,
    );

    final hasPreviousWeek =
        weekNumber > 1 &&
        (input['previous_week_history'] as List?)?.isNotEmpty == true;

    return '''
You are creating an executive communication lesson packet for one training week.

Goal:
- Prepare the user for this week's scheduled drills.
- Teach the topic before each drill starts.
- Show what strong execution looks like.
- Analyze the user's specific development areas on each topic using prior responses and coaching history.
- Craft a unique, personalized drill question for each plan item based on the user's role, industry, and development focus.
- Treat ai_scenario_context and ai_prompt_text as the exact scenario and question that will be shown to the user next week.
${hasPreviousWeek ? '- Evaluate the prior week\'s responses and provide honest AI scoring and observations.' : ''}

Rules:
- Return JSON only.
- Do not wrap the JSON in markdown.
- Keep every drill aligned to the existing scheduled plan item type and difficulty.
- Use the prior week's answers and coaching to personalize the development focus.
- Use recent same-topic history to call out recurring strengths and weaknesses.
- Keep lesson content concise, practical, and coaching-oriented.
- Every current-week plan item must appear exactly once in the drills array.
- Craft ai_scenario_context and ai_prompt_text for every drill — make them specific to the user's industry and role, not generic.
- Add drill_purpose for every drill as one sentence explaining what that exercise is training.
- Add exactly 3 success_signals for every drill so the user knows what a strong answer looks like.

Inputs:
${_prettyJson.convert(input)}

Return this exact JSON shape:
{
  "week_number": $weekNumber,
  "weekly_objective": "One clear sentence describing the week's coaching goal.",
  "development_summary": "A concise analysis of the user's development needs entering this week.",
  "previous_week_analysis": ${hasPreviousWeek ? '"A coaching narrative evaluating the prior week\'s responses: what improved, what persists, and what to prioritize this week."' : '""'},
  "previous_week_evaluations": ${hasPreviousWeek ? '[{"session_id": "uuid-from-previous-week-history", "ai_score": 72, "key_observations": ["Observation about this response"]}]' : '[]'},
  "drills": [
    {
      "plan_item_id": "exact-plan-item-id",
      "lesson_title": "Short title",
      "lesson_body": "Teach the skill for this drill.",
      "good_example": "A strong example response for this drill.",
      "example_analysis": "Why the example works.",
      "user_development_focus": "How this user should improve on this topic based on prior responses.",
      "pre_drill_checklist": [
        "Short checklist item",
        "Short checklist item"
      ],
      "drill_purpose": "One sentence explaining what this drill is training.",
      "success_signals": [
        "Concrete sign of a strong answer",
        "Concrete sign of a strong answer",
        "Concrete sign of a strong answer"
      ],
      "ai_scenario_context": "A realistic scenario paragraph tailored to the user's role and industry.",
      "ai_prompt_text": "The specific question or prompt the user will respond to in this drill."
    }
  ]
}
''';
  }

  static Map<String, dynamic> buildPromptInput({
    required int weekNumber,
    required TrainingPlan plan,
    required CommunicationBaseline baseline,
    ProgressSnapshot? progress,
    required List<TrainingSession> sessions,
    WeeklyLessonPacket? previousWeekPacket,
  }) {
    final weekItems = _weekItems(plan, weekNumber);
    if (weekItems.isEmpty) {
      throw StateError('Week $weekNumber has no scheduled plan items.');
    }

    final previousWeekIds = _weekItems(
      plan,
      weekNumber - 1,
    ).map((item) => item.id).toSet();
    final currentCategories = weekItems.map((item) => item.drillType).toSet();
    final currentPromptIds = weekItems.map((item) => item.promptId).toSet();

    final previousWeekHistory = sessions
        .where(
          (session) =>
              session.planItemId != null &&
              previousWeekIds.contains(session.planItemId) &&
              session.reviews.isNotEmpty,
        )
        .map(_sessionHistorySummary)
        .toList();

    final recentSameTopicHistory =
        sessions
            .where(
              (session) =>
                  session.reviews.isNotEmpty &&
                  (currentPromptIds.contains(session.prompt.id) ||
                      currentCategories.contains(
                        session.prompt.category.label,
                      )),
            )
            .toList()
          ..sort((a, b) {
            final left = a.completedAt ?? a.startedAt;
            final right = b.completedAt ?? b.startedAt;
            return right.compareTo(left);
          });

    return {
      'plan': {
        'plan_id': plan.id,
        'plan_version_id': plan.currentVersion.id,
        'week_number': weekNumber,
        'plan_summary': plan.currentVersion.rationaleText,
        'week_items': [
          for (final item in weekItems)
            {
              'plan_item_id': item.id,
              'day_number': item.dayNumber,
              'sequence_number': item.sequenceNumber,
              'scheduled_for': item.scheduledFor.toIso8601String(),
              'drill_type': item.drillType,
              'difficulty_tier': item.difficultyTier,
              'focus_pillars': item.focusPillars
                  .map((pillar) => pillar.label)
                  .toList(),
              'target_metrics': item.targetMetrics,
            },
        ],
      },
      'baseline': {
        'assigned_level': baseline.assignedLevel.label,
        'overall_score': baseline.overallScore,
        'readiness_score': baseline.readinessScore,
        'strength_pillars': baseline.strengthPillars
            .map((pillar) => pillar.label)
            .toList(),
        'weak_pillars': baseline.weakPillars
            .map((pillar) => pillar.label)
            .toList(),
        'summary_text': baseline.summaryText,
      },
      'progress': progress == null
          ? null
          : {
              'current_level': progress.currentLevel.label,
              'readiness_score': progress.readinessScore,
              'weekly_completion_rate': progress.weeklyCompletionRate,
              'coaching_adoption_rate': progress.coachingAdoptionRate,
              'difficulty_tolerance': progress.difficultyTolerance,
              'latest_recalibration_state':
                  progress.latestRecalibrationState.label,
              'pillar_scores': {
                for (final entry in progress.pillarScores.entries)
                  entry.key.label: entry.value,
              },
            },
      'previous_week_history': previousWeekHistory,
      'recent_same_topic_history': [
        for (final session in recentSameTopicHistory.take(6))
          _sessionHistorySummary(session),
      ],
      if (previousWeekPacket != null &&
          previousWeekPacket.previousWeekEvaluations.isNotEmpty)
        'previous_week_ai_evaluations': [
          for (final e in previousWeekPacket.previousWeekEvaluations)
            {
              'session_id': e.sessionId,
              'ai_score': e.aiScore,
              'key_observations': e.keyObservations,
            },
        ],
    };
  }

  static String _stripMarkdownFences(String text) {
    // Strip BOM and other common invisible leading characters before trimming.
    var cleaned = text.replaceAll('﻿', '').trim();
    final fencePattern = RegExp(r'^```(?:json)?\s*\n?([\s\S]*?)\n?```\s*$');
    final match = fencePattern.firstMatch(cleaned);
    return match != null ? match.group(1)!.trim() : cleaned;
  }

  static ValidatedWeeklyLessonPacketImport parseImport({
    required int expectedWeekNumber,
    required List<PlanItem> weekItems,
    required String rawJson,
  }) {
    final cleaned = _stripMarkdownFences(rawJson);
    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (error) {
      throw FormatException('The AI response is not valid JSON: $error');
    }
    if (decoded is! Map) {
      throw const FormatException('The AI response must be a JSON object.');
    }

    final map = Map<String, dynamic>.from(decoded);
    final weekNumber = _requiredInt(map, 'week_number');
    if (weekNumber != expectedWeekNumber) {
      throw FormatException(
        'The AI response is for week $weekNumber, but week '
        '$expectedWeekNumber was expected.',
      );
    }

    final weeklyObjective = _requiredString(map, 'weekly_objective');
    final developmentSummary = _requiredString(map, 'development_summary');
    final previousWeekAnalysis =
        map['previous_week_analysis']?.toString().trim() ?? '';

    final previousWeekEvaluations = <WeeklySessionEvaluation>[];
    final evalList = map['previous_week_evaluations'];
    if (evalList is List) {
      for (final entry in evalList) {
        if (entry is Map) {
          final e = Map<String, dynamic>.from(entry);
          final sessionId = e['session_id']?.toString() ?? '';
          if (sessionId.isEmpty) continue;
          final aiScore = (e['ai_score'] is num)
              ? (e['ai_score'] as num).toDouble()
              : double.tryParse(e['ai_score']?.toString() ?? '') ?? 0;
          final observations = (e['key_observations'] is List)
              ? (e['key_observations'] as List)
                    .map((o) => o.toString())
                    .where((o) => o.isNotEmpty)
                    .toList()
              : <String>[];
          previousWeekEvaluations.add(
            WeeklySessionEvaluation(
              sessionId: sessionId,
              aiScore: aiScore,
              keyObservations: observations,
            ),
          );
        }
      }
    }

    final drillsValue = map['drills'];
    if (drillsValue is! List) {
      throw const FormatException('The "drills" field must be a JSON array.');
    }

    final expectedIds = weekItems.map((item) => item.id).toSet();
    final seenIds = <String>{};
    final drills = <WeeklyDrillLesson>[];

    for (var index = 0; index < drillsValue.length; index++) {
      final row = drillsValue[index];
      if (row is! Map) {
        throw FormatException(
          'Drill entry ${index + 1} must be a JSON object.',
        );
      }
      final drill = Map<String, dynamic>.from(row);
      final planItemId = _requiredString(drill, 'plan_item_id');
      if (!expectedIds.contains(planItemId)) {
        throw FormatException(
          'Drill entry ${index + 1} references unknown plan_item_id '
          '"$planItemId".',
        );
      }
      if (!seenIds.add(planItemId)) {
        throw FormatException(
          'The AI response contains duplicate plan_item_id "$planItemId".',
        );
      }

      final checklistValue = drill['pre_drill_checklist'];
      if (checklistValue is! List) {
        throw FormatException(
          'Drill entry ${index + 1} must include a "pre_drill_checklist" array.',
        );
      }
      final checklist = checklistValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (checklist.isEmpty) {
        throw FormatException(
          'Drill entry ${index + 1} must include at least one checklist item.',
        );
      }

      final successSignalsValue = drill['success_signals'];
      if (successSignalsValue is! List) {
        throw FormatException(
          'Drill entry ${index + 1} must include a "success_signals" array.',
        );
      }
      final successSignals = successSignalsValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (successSignals.length != 3) {
        throw FormatException(
          'Drill entry ${index + 1} must include exactly 3 success_signals.',
        );
      }

      final aiScenarioContext = drill['ai_scenario_context']?.toString().trim();
      final aiPromptText = drill['ai_prompt_text']?.toString().trim();

      drills.add(
        WeeklyDrillLesson(
          planItemId: planItemId,
          lessonTitle: _requiredString(drill, 'lesson_title'),
          lessonBody: _requiredString(drill, 'lesson_body'),
          goodExample: _requiredString(drill, 'good_example'),
          exampleAnalysis: _requiredString(drill, 'example_analysis'),
          userDevelopmentFocus: _requiredString(
            drill,
            'user_development_focus',
          ),
          preDrillChecklist: checklist,
          drillPurpose: _requiredString(drill, 'drill_purpose'),
          successSignals: successSignals,
          aiScenarioContext: (aiScenarioContext?.isNotEmpty == true)
              ? aiScenarioContext
              : null,
          aiPromptText: (aiPromptText?.isNotEmpty == true)
              ? aiPromptText
              : null,
        ),
      );
    }

    final missingIds = expectedIds.difference(seenIds);
    if (missingIds.isNotEmpty) {
      throw FormatException(
        'The AI response is missing lesson entries for: '
        '${missingIds.join(', ')}.',
      );
    }

    return ValidatedWeeklyLessonPacketImport(
      weekNumber: weekNumber,
      weeklyObjective: weeklyObjective,
      developmentSummary: developmentSummary,
      rawImportText: cleaned,
      drills: drills,
      previousWeekAnalysis: previousWeekAnalysis,
      previousWeekEvaluations: previousWeekEvaluations,
    );
  }

  static List<PlanItem> _weekItems(TrainingPlan plan, int weekNumber) {
    return plan.currentVersion.items
        .where((item) => item.weekNumber == weekNumber)
        .toList()
      ..sort((a, b) {
        final dayCompare = a.dayNumber.compareTo(b.dayNumber);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return a.sequenceNumber.compareTo(b.sequenceNumber);
      });
  }

  static Map<String, dynamic> _sessionHistorySummary(TrainingSession session) {
    final review = session.reviews.isEmpty ? null : session.reviews.last;
    final attempt = session.attempts.isEmpty
        ? null
        : session.attempts[(session.bestAttemptNo ?? session.attempts.length) -
              1];
    return {
      'session_id': session.id,
      'plan_item_id': session.planItemId,
      'prompt_title': session.prompt.title,
      'prompt_category': session.prompt.category.code,
      'response_text': attempt?.responseText ?? '',
      'overall_score': review?.score.overallScore,
      'biggest_issue': review?.feedback.biggestIssue ?? '',
      'top_coaching_points': review?.feedback.topCoachingPoints ?? const [],
      'next_attempt_target': review?.feedback.nextAttemptTarget ?? '',
    };
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('The "$key" field is required.');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('The "$key" field must be an integer.');
    }
    return parsed;
  }
}
