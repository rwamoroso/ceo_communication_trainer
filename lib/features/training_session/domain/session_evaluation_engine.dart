import 'dart:convert';

import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/scoring_engine.dart';

class ParsedSessionEvaluationImport {
  const ParsedSessionEvaluationImport({
    required this.rawImportText,
    required this.scoredAttempt,
    this.nextDayDrillUpdate,
  });

  final String rawImportText;
  final ScoredAttempt scoredAttempt;
  final NextDayDrillUpdate? nextDayDrillUpdate;
}

class NextDayDrillUpdate {
  const NextDayDrillUpdate({
    required this.planItemId,
    required this.adjustmentReason,
    this.userDevelopmentFocus,
    this.drillPurpose,
    this.successSignals,
    this.preDrillChecklist,
    this.aiScenarioContext,
    this.aiPromptText,
  });

  final String planItemId;
  final String adjustmentReason;
  final String? userDevelopmentFocus;
  final String? drillPurpose;
  final List<String>? successSignals;
  final List<String>? preDrillChecklist;
  final String? aiScenarioContext;
  final String? aiPromptText;
}

class SessionEvaluationEngine {
  static const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

  static String buildPrompt({required Map<String, dynamic> input}) {
    return '''
You are scoring one executive communication drill attempt.

Rules:
- Return JSON only.
- Do not wrap the JSON in markdown.
- Score the response against the drill purpose, success signals, prompt, and weekly lesson context.
- Be honest and specific. Do not inflate the score to be polite.
- Keep the written coaching consistent with the numeric scoring.
- Give at most 3 top_coaching_points.
- Keep the improved example concise enough to fit the target duration.
- For typed responses, filler_words_per_minute and words_per_minute may be null.
- If a next scheduled drill is provided in the inputs, decide whether it should be updated based on this user's current needs. If so, return a focused next_day_drill_update.

Inputs:
${_prettyJson.convert(input)}

Return this exact JSON shape:
{
  "overall_score": 64,
  "pillar_scores": {
    "clarity": 68,
    "structure": 60,
    "brevity": 55,
    "presence": 62,
    "strategic_framing": 58,
    "pressure_response": 54
  },
  "behavior_metrics": {
    "direct_answer_rate": 0.4,
    "bluf_usage_rate": 0.2,
    "clean_three_point_structure_rate": 0.35,
    "average_response_length_words": 96,
    "filler_words_per_minute": null,
    "words_per_minute": null,
    "retry_count": 0,
    "coaching_adoption_rate": 0.45,
    "consistency": 0.58,
    "missed_sessions": 0,
    "difficulty_tolerance": 0.52
  },
  "biggest_issue": "You delayed the answer.",
  "secondary_issue": "Your middle section wandered.",
  "what_worked": "Your recommendation became clearer near the end.",
  "top_coaching_points": [
    "Lead with the answer in one sentence.",
    "Use exactly three points.",
    "Cut the setup in half."
  ],
  "improved_example_answer": "My recommendation is X for three reasons...",
  "next_attempt_target": "State the recommendation in the first sentence and keep the whole response under 45 seconds.",
  "next_day_drill_update": {
    "plan_item_id": "exact-next-plan-item-id",
    "adjustment_reason": "One sentence explaining why the next drill should be tightened or reframed.",
    "user_development_focus": "A revised focus for the next drill.",
    "drill_purpose": "An updated one-sentence purpose for the next drill.",
    "success_signals": [
      "Concrete sign of a strong next answer",
      "Concrete sign of a strong next answer",
      "Concrete sign of a strong next answer"
    ],
    "pre_drill_checklist": [
      "Short checklist item",
      "Short checklist item"
    ],
    "ai_scenario_context": "A revised scenario for the next drill.",
    "ai_prompt_text": "A revised exact question for the next drill."
  }
}
''';
  }

  static ParsedSessionEvaluationImport parseImport({
    required String rawJson,
    String scoringVersion = 'manual-ai-v1',
    String feedbackVersion = 'manual-ai-v1',
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

    final payload = Map<String, dynamic>.from(decoded);
    final pillarScores = _requiredMap(payload, 'pillar_scores');
    final behaviorMetrics = _requiredMap(payload, 'behavior_metrics');
    final biggestIssue = _requiredString(payload, 'biggest_issue');
    final improvedExample = _requiredString(payload, 'improved_example_answer');
    final nextAttemptTarget = _requiredString(payload, 'next_attempt_target');
    final coachingPoints = _requiredStringList(
      payload,
      'top_coaching_points',
      minimum: 1,
      maximum: 3,
    );

    final scoringVersionValue =
        payload['scoring_version']?.toString().trim() ?? '';
    final feedbackVersionValue =
        payload['feedback_version']?.toString().trim() ?? '';
    final nextDayDrillUpdate = _parseNextDayDrillUpdate(payload);

    final scoredAttempt = ScoredAttempt(
      score: SessionScore(
        overallScore: _requiredDouble(payload, 'overall_score'),
        pillarScores: {
          Pillar.clarity: _requiredDouble(pillarScores, 'clarity'),
          Pillar.structure: _requiredDouble(pillarScores, 'structure'),
          Pillar.brevity: _requiredDouble(pillarScores, 'brevity'),
          Pillar.presence: _requiredDouble(pillarScores, 'presence'),
          Pillar.strategicFraming: _requiredDouble(
            pillarScores,
            'strategic_framing',
          ),
          Pillar.pressureResponse: _requiredDouble(
            pillarScores,
            'pressure_response',
          ),
        },
        behaviorMetrics: BehaviorMetrics(
          directAnswerRate: _requiredDouble(
            behaviorMetrics,
            'direct_answer_rate',
          ),
          blufUsageRate: _requiredDouble(behaviorMetrics, 'bluf_usage_rate'),
          cleanThreePointStructureRate: _requiredDouble(
            behaviorMetrics,
            'clean_three_point_structure_rate',
          ),
          averageResponseLengthWords: _requiredDouble(
            behaviorMetrics,
            'average_response_length_words',
          ),
          fillerWordsPerMinute: _optionalDouble(
            behaviorMetrics,
            'filler_words_per_minute',
          ),
          wordsPerMinute: _optionalDouble(behaviorMetrics, 'words_per_minute'),
          retryCount: _optionalInt(behaviorMetrics, 'retry_count'),
          coachingAdoptionRate:
              _optionalDouble(behaviorMetrics, 'coaching_adoption_rate') ?? 0,
          consistency: _optionalDouble(behaviorMetrics, 'consistency') ?? 0,
          missedSessions: _optionalInt(behaviorMetrics, 'missed_sessions'),
          difficultyTolerance:
              _optionalDouble(behaviorMetrics, 'difficulty_tolerance') ?? 0,
        ),
        scoringVersion: scoringVersionValue.isNotEmpty
            ? scoringVersionValue
            : scoringVersion,
      ),
      feedback: SessionFeedback(
        biggestIssue: biggestIssue,
        secondaryIssue: payload['secondary_issue']?.toString().trim() ?? '',
        whatWorked: payload['what_worked']?.toString().trim() ?? '',
        topCoachingPoints: coachingPoints,
        improvedExampleAnswer: improvedExample,
        nextAttemptTarget: nextAttemptTarget,
        feedbackVersion: feedbackVersionValue.isNotEmpty
            ? feedbackVersionValue
            : feedbackVersion,
      ),
    );

    return ParsedSessionEvaluationImport(
      rawImportText: cleaned,
      scoredAttempt: scoredAttempt,
      nextDayDrillUpdate: nextDayDrillUpdate,
    );
  }

  static String _stripMarkdownFences(String text) {
    var cleaned = text.replaceAll('﻿', '').trim();
    final fencePattern = RegExp(r'^```(?:json)?\s*\n?([\s\S]*?)\n?```\s*$');
    final match = fencePattern.firstMatch(cleaned);
    return match != null ? match.group(1)!.trim() : cleaned;
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw FormatException('The "$key" field must be a JSON object.');
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('The "$key" field is required.');
    }
    return value;
  }

  static List<String> _requiredStringList(
    Map<String, dynamic> map,
    String key, {
    required int minimum,
    required int maximum,
  }) {
    final value = map[key];
    if (value is! List) {
      throw FormatException('The "$key" field must be a JSON array.');
    }

    final items = value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    if (items.length < minimum || items.length > maximum) {
      throw FormatException(
        'The "$key" field must contain between $minimum and $maximum items.',
      );
    }
    return items;
  }

  static double _requiredDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is num) {
      return value.toDouble();
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('The "$key" field must be a number.');
    }
    return parsed;
  }

  static double? _optionalDouble(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key) || map[key] == null) {
      return null;
    }
    return _requiredDouble(map, key);
  }

  static int _optionalInt(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key) || map[key] == null) {
      return 0;
    }
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value.toString());
    if (parsed == null) {
      throw FormatException('The "$key" field must be an integer.');
    }
    return parsed;
  }

  static NextDayDrillUpdate? _parseNextDayDrillUpdate(
    Map<String, dynamic> payload,
  ) {
    final value = payload['next_day_drill_update'];
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw const FormatException(
        'The "next_day_drill_update" field must be a JSON object when provided.',
      );
    }

    final update = Map<String, dynamic>.from(value);
    final planItemId = _requiredString(update, 'plan_item_id');
    final adjustmentReason = _requiredString(update, 'adjustment_reason');
    final successSignals = update.containsKey('success_signals')
        ? _requiredStringList(update, 'success_signals', minimum: 3, maximum: 3)
        : null;
    final checklist = update.containsKey('pre_drill_checklist')
        ? _requiredStringList(
            update,
            'pre_drill_checklist',
            minimum: 1,
            maximum: 6,
          )
        : null;

    return NextDayDrillUpdate(
      planItemId: planItemId,
      adjustmentReason: adjustmentReason,
      userDevelopmentFocus: update['user_development_focus']?.toString().trim(),
      drillPurpose: update['drill_purpose']?.toString().trim(),
      successSignals: successSignals,
      preDrillChecklist: checklist,
      aiScenarioContext: update['ai_scenario_context']?.toString().trim(),
      aiPromptText: update['ai_prompt_text']?.toString().trim(),
    );
  }
}
