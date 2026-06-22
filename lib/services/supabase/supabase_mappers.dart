import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

double asDouble(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value == null) {
    return fallback;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? fallback;
}

DateTime parseDbTimestamp(dynamic value) {
  return DateTime.parse(value.toString()).toLocal();
}

DateTime parseDbDate(dynamic value) {
  return DateTime.parse(value.toString());
}

String toDbDate(DateTime value) => value.toIso8601String().split('T').first;

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const [];
}

AppUser appUserFromSupabaseUser(User user) {
  return AppUser(id: user.id, email: user.email ?? '');
}

String communicationLevelToDb(CommunicationLevel level) => switch (level) {
  CommunicationLevel.reactive => 'reactive',
  CommunicationLevel.understandable => 'understandable',
  CommunicationLevel.structured => 'structured',
  CommunicationLevel.managerReady => 'manager_ready',
  CommunicationLevel.directorReady => 'director_ready',
  CommunicationLevel.executiveReady => 'executive_ready',
  CommunicationLevel.ceoLevel => 'ceo_level',
};

CommunicationLevel communicationLevelFromDb(String value) => switch (value) {
  'reactive' => CommunicationLevel.reactive,
  'understandable' => CommunicationLevel.understandable,
  'structured' => CommunicationLevel.structured,
  'manager_ready' => CommunicationLevel.managerReady,
  'director_ready' => CommunicationLevel.directorReady,
  'executive_ready' => CommunicationLevel.executiveReady,
  'ceo_level' => CommunicationLevel.ceoLevel,
  _ => CommunicationLevel.reactive,
};

String promptCategoryToDb(PromptCategory category) => switch (category) {
  PromptCategory.blufStructuredThinking => 'bluf_structured_thinking',
  PromptCategory.directAnswerDiscipline => 'direct_answer_discipline',
  PromptCategory.brevityCompression => 'brevity_compression',
  PromptCategory.executivePresence => 'executive_presence',
  PromptCategory.strategicFraming => 'strategic_framing',
  PromptCategory.pressureResponse => 'pressure_response',
  PromptCategory.listeningSummarization => 'listening_summarization',
};

PromptCategory promptCategoryFromDb(String value) => switch (value) {
  'bluf_structured_thinking' => PromptCategory.blufStructuredThinking,
  'direct_answer_discipline' => PromptCategory.directAnswerDiscipline,
  'brevity_compression' => PromptCategory.brevityCompression,
  'executive_presence' => PromptCategory.executivePresence,
  'strategic_framing' => PromptCategory.strategicFraming,
  'pressure_response' => PromptCategory.pressureResponse,
  'listening_summarization' => PromptCategory.listeningSummarization,
  _ => PromptCategory.directAnswerDiscipline,
};

String recalibrationStateToDb(RecalibrationState state) => switch (state) {
  RecalibrationState.accelerating => 'accelerating',
  RecalibrationState.stable => 'stable',
  RecalibrationState.plateau => 'plateau',
  RecalibrationState.regressing => 'regressing',
};

RecalibrationState recalibrationStateFromDb(String value) => switch (value) {
  'accelerating' => RecalibrationState.accelerating,
  'stable' => RecalibrationState.stable,
  'plateau' => RecalibrationState.plateau,
  'regressing' => RecalibrationState.regressing,
  _ => RecalibrationState.stable,
};

String sessionStatusToDb(SessionStatus status) => switch (status) {
  SessionStatus.inProgress => 'in_progress',
  SessionStatus.completed => 'completed',
};

SessionStatus sessionStatusFromDb(String value) => switch (value) {
  'in_progress' => SessionStatus.inProgress,
  'completed' => SessionStatus.completed,
  _ => SessionStatus.inProgress,
};

String planItemStatusToDb(PlanItemStatus status) => switch (status) {
  PlanItemStatus.scheduled => 'scheduled',
  PlanItemStatus.completed => 'completed',
  PlanItemStatus.missed => 'missed',
  PlanItemStatus.skipped => 'skipped',
};

PlanItemStatus planItemStatusFromDb(String value) => switch (value) {
  'scheduled' => PlanItemStatus.scheduled,
  'completed' => PlanItemStatus.completed,
  'missed' => PlanItemStatus.missed,
  'skipped' => PlanItemStatus.skipped,
  _ => PlanItemStatus.scheduled,
};

String responseModeToDb(ResponseMode mode) => switch (mode) {
  ResponseMode.typed => 'typed',
  ResponseMode.audio => 'audio',
};

ResponseMode responseModeFromDb(String value) => switch (value) {
  'typed' => ResponseMode.typed,
  'audio' => ResponseMode.audio,
  _ => ResponseMode.typed,
};

String sessionOriginToDb(SessionOrigin origin) => switch (origin) {
  SessionOrigin.baseline => 'baseline',
  SessionOrigin.dailyPlan => 'daily_plan',
};

SessionOrigin sessionOriginFromDb(String value) => switch (value) {
  'baseline' => SessionOrigin.baseline,
  'daily_plan' => SessionOrigin.dailyPlan,
  _ => SessionOrigin.baseline,
};

String seniorityBandToDb(SeniorityBand band) => switch (band) {
  SeniorityBand.emergingManager => 'emerging_manager',
  SeniorityBand.manager => 'manager',
  SeniorityBand.seniorManager => 'senior_manager',
  SeniorityBand.director => 'director',
  SeniorityBand.vicePresident => 'vice_president',
  SeniorityBand.founder => 'founder',
};

SeniorityBand seniorityBandFromDb(String value) => switch (value) {
  'emerging_manager' => SeniorityBand.emergingManager,
  'manager' => SeniorityBand.manager,
  'senior_manager' => SeniorityBand.seniorManager,
  'director' => SeniorityBand.director,
  'vice_president' => SeniorityBand.vicePresident,
  'founder' => SeniorityBand.founder,
  _ => SeniorityBand.manager,
};

String pillarToDb(Pillar pillar) => switch (pillar) {
  Pillar.clarity => 'clarity',
  Pillar.structure => 'structure',
  Pillar.brevity => 'brevity',
  Pillar.presence => 'presence',
  Pillar.strategicFraming => 'strategic_framing',
  Pillar.pressureResponse => 'pressure_response',
};

Pillar pillarFromDb(String value) => switch (value) {
  'clarity' => Pillar.clarity,
  'structure' => Pillar.structure,
  'brevity' => Pillar.brevity,
  'presence' => Pillar.presence,
  'strategic_framing' => Pillar.strategicFraming,
  'strategicFraming' => Pillar.strategicFraming,
  'pressure_response' => Pillar.pressureResponse,
  'pressureResponse' => Pillar.pressureResponse,
  _ => Pillar.clarity,
};

List<String> stringListFromDb(dynamic value) {
  return asList(value).map((item) => item.toString()).toList();
}

List<Pillar> pillarListFromDb(dynamic value) {
  return asList(value).map((item) => pillarFromDb(item.toString())).toList();
}

Map<String, double> doubleMapFromDb(dynamic value) {
  final map = asMap(value);
  return {for (final entry in map.entries) entry.key: asDouble(entry.value)};
}

Map<Pillar, double> pillarWeightMapFromDb(dynamic value) {
  final map = asMap(value);
  return {
    for (final entry in map.entries)
      pillarFromDb(entry.key): asDouble(entry.value),
  };
}

Map<String, dynamic> pillarWeightMapToDb(Map<Pillar, double> value) {
  return {
    for (final entry in value.entries) pillarToDb(entry.key): entry.value,
  };
}

Map<String, dynamic> behaviorMetricsToDb(BehaviorMetrics value) {
  return {
    'direct_answer_rate': value.directAnswerRate,
    'bluf_usage_rate': value.blufUsageRate,
    'clean_three_point_structure_rate': value.cleanThreePointStructureRate,
    'average_response_length_words': value.averageResponseLengthWords,
    'filler_words_per_minute': value.fillerWordsPerMinute,
    'words_per_minute': value.wordsPerMinute,
    'retry_count': value.retryCount,
    'coaching_adoption_rate': value.coachingAdoptionRate,
    'consistency': value.consistency,
    'missed_sessions': value.missedSessions,
    'difficulty_tolerance': value.difficultyTolerance,
  };
}

BehaviorMetrics behaviorMetricsFromDb(dynamic value) {
  final map = asMap(value);
  final fillerWordsPerMinute = map['filler_words_per_minute'];
  final wordsPerMinute = map['words_per_minute'];
  return BehaviorMetrics(
    directAnswerRate: asDouble(map['direct_answer_rate']),
    blufUsageRate: asDouble(map['bluf_usage_rate']),
    cleanThreePointStructureRate: asDouble(
      map['clean_three_point_structure_rate'],
    ),
    averageResponseLengthWords: asDouble(map['average_response_length_words']),
    fillerWordsPerMinute: fillerWordsPerMinute == null
        ? null
        : asDouble(fillerWordsPerMinute),
    wordsPerMinute: wordsPerMinute == null ? null : asDouble(wordsPerMinute),
    retryCount: asInt(map['retry_count']),
    coachingAdoptionRate: asDouble(map['coaching_adoption_rate']),
    consistency: asDouble(map['consistency']),
    missedSessions: asInt(map['missed_sessions']),
    difficultyTolerance: asDouble(map['difficulty_tolerance']),
  );
}

UserProfile userProfileFromRow(Map<String, dynamic> row) {
  return UserProfile(
    userId: row['id'].toString(),
    displayName: row['display_name']?.toString() ?? '',
    roleTitle: row['role_title']?.toString() ?? '',
    seniorityBand: seniorityBandFromDb(row['seniority_band']?.toString() ?? ''),
    industry: row['industry']?.toString() ?? '',
    timezone: row['timezone']?.toString() ?? 'UTC',
    weeklyGoalCount: asInt(row['weekly_goal_count'], fallback: 5),
    communicationContexts: stringListFromDb(row['communication_contexts']),
    goals: stringListFromDb(row['goals']),
    microphoneConsent: row['microphone_consent'] == true,
    preferredResponseMode: responseModeFromDb(
      row['preferred_response_mode']?.toString() ?? 'typed',
    ),
    dailyReminderTime: row['daily_reminder_time']?.toString() ?? '',
    onboardingCompletedAt: row['onboarding_completed_at'] == null
        ? null
        : parseDbTimestamp(row['onboarding_completed_at']),
    baselineCompletedAt: row['baseline_completed_at'] == null
        ? null
        : parseDbTimestamp(row['baseline_completed_at']),
  );
}

PromptTemplate promptTemplateFromRow(Map<String, dynamic> row) {
  return PromptTemplate(
    id: row['id'].toString(),
    slug: row['slug'].toString(),
    title: row['title'].toString(),
    category: promptCategoryFromDb(row['category'].toString()),
    difficultyTier: asInt(row['difficulty_tier'], fallback: 1),
    scenarioContext: row['scenario_context'].toString(),
    promptText: row['prompt_text'].toString(),
    targetDurationSec: asInt(row['target_duration_sec'], fallback: 45),
    targetWordRangeMin: asInt(row['target_word_range_min'], fallback: 50),
    targetWordRangeMax: asInt(row['target_word_range_max'], fallback: 80),
    pillarWeights: pillarWeightMapFromDb(row['pillar_weights']),
    behaviorTargets: doubleMapFromDb(row['behavior_targets']),
  );
}

PlanItem planItemFromRow(Map<String, dynamic> row) {
  return PlanItem(
    id: row['id'].toString(),
    promptId: row['prompt_id'].toString(),
    weekNumber: asInt(row['week_number'], fallback: 1),
    dayNumber: asInt(row['day_number'], fallback: 1),
    sequenceNumber: asInt(row['sequence_number'], fallback: 1),
    scheduledFor: parseDbDate(row['scheduled_for']),
    drillType: row['drill_type']?.toString() ?? '',
    focusPillars: pillarListFromDb(row['focus_pillars']),
    difficultyTier: asInt(row['difficulty_tier'], fallback: 1),
    targetMetrics: doubleMapFromDb(row['target_metrics']),
    status: planItemStatusFromDb(row['status'].toString()),
  );
}

TrainingPlanVersion trainingPlanVersionFromRow(
  Map<String, dynamic> row, {
  required List<PlanItem> items,
}) {
  return TrainingPlanVersion(
    id: row['id'].toString(),
    versionNumber: asInt(row['version_number'], fallback: 1),
    source: row['source']?.toString() ?? '',
    generatedAt: parseDbTimestamp(row['generated_at']),
    rationaleText: row['rationale_text']?.toString() ?? '',
    items: items,
  );
}

TrainingPlan trainingPlanFromRows({
  required Map<String, dynamic> planRow,
  required TrainingPlanVersion currentVersion,
  required List<TrainingPlanVersion> previousVersions,
}) {
  return TrainingPlan(
    id: planRow['id'].toString(),
    userId: planRow['user_id'].toString(),
    startDate: parseDbDate(planRow['start_date']),
    targetEndDate: parseDbDate(planRow['target_end_date']),
    status: planRow['status']?.toString() ?? 'active',
    currentVersion: currentVersion,
    previousVersions: previousVersions,
  );
}

WeeklyLessonPacket weeklyLessonPacketFromRow(Map<String, dynamic> row) {
  final payload = asMap(row['packet_payload']);
  final drills = asList(payload['drills']).map((entry) {
    final map = asMap(entry);
    final aiScenarioContext = map['ai_scenario_context']?.toString().trim();
    final aiPromptText = map['ai_prompt_text']?.toString().trim();
    return WeeklyDrillLesson(
      planItemId: map['plan_item_id']?.toString() ?? '',
      lessonTitle: map['lesson_title']?.toString() ?? '',
      lessonBody: map['lesson_body']?.toString() ?? '',
      goodExample: map['good_example']?.toString() ?? '',
      exampleAnalysis: map['example_analysis']?.toString() ?? '',
      userDevelopmentFocus: map['user_development_focus']?.toString() ?? '',
      preDrillChecklist: stringListFromDb(map['pre_drill_checklist']),
      drillPurpose: map['drill_purpose']?.toString() ?? '',
      successSignals: stringListFromDb(map['success_signals']),
      aiScenarioContext: (aiScenarioContext?.isNotEmpty == true)
          ? aiScenarioContext
          : null,
      aiPromptText: (aiPromptText?.isNotEmpty == true) ? aiPromptText : null,
    );
  }).toList();

  final previousWeekEvaluations = asList(payload['previous_week_evaluations'])
      .map((entry) {
        final map = asMap(entry);
        return WeeklySessionEvaluation(
          sessionId: map['session_id']?.toString() ?? '',
          aiScore: asDouble(map['ai_score']),
          keyObservations: stringListFromDb(map['key_observations']),
        );
      })
      .where((e) => e.sessionId.isNotEmpty)
      .toList();

  return WeeklyLessonPacket(
    id: row['id'].toString(),
    planVersionId: row['plan_version_id'].toString(),
    weekNumber: asInt(row['week_number'], fallback: 1),
    weeklyObjective:
        row['weekly_objective']?.toString() ??
        payload['weekly_objective']?.toString() ??
        '',
    developmentSummary:
        row['development_summary']?.toString() ??
        payload['development_summary']?.toString() ??
        '',
    rawImportText: row['raw_import_text']?.toString() ?? '',
    drills: drills,
    createdAt: parseDbTimestamp(row['created_at']),
    updatedAt: parseDbTimestamp(row['updated_at']),
    previousWeekAnalysis: payload['previous_week_analysis']?.toString() ?? '',
    previousWeekEvaluations: previousWeekEvaluations,
  );
}

SessionAttempt sessionAttemptFromRow(Map<String, dynamic> row) {
  return SessionAttempt(
    id: row['id'].toString(),
    attemptNo: asInt(row['attempt_no'], fallback: 1),
    responseMode: responseModeFromDb(
      row['response_mode']?.toString() ?? 'typed',
    ),
    responseText: row['transcript_text']?.toString() ?? '',
    durationSeconds: (asInt(row['duration_ms']) / 1000).round(),
    wordCount: asInt(row['word_count']),
    submittedAt: parseDbTimestamp(row['submitted_at']),
  );
}

SessionScore sessionScoreFromRow(Map<String, dynamic> row) {
  return SessionScore(
    overallScore: asDouble(row['overall_score']),
    pillarScores: {
      Pillar.clarity: asDouble(row['clarity_score']),
      Pillar.structure: asDouble(row['structure_score']),
      Pillar.brevity: asDouble(row['brevity_score']),
      Pillar.presence: asDouble(row['presence_score']),
      Pillar.strategicFraming: asDouble(row['strategic_framing_score']),
      Pillar.pressureResponse: asDouble(row['pressure_response_score']),
    },
    behaviorMetrics: behaviorMetricsFromDb(row['behavior_metrics']),
    scoringVersion: row['scoring_version']?.toString() ?? 'v1',
  );
}

SessionFeedback sessionFeedbackFromRow(Map<String, dynamic> row) {
  return SessionFeedback(
    biggestIssue: row['biggest_issue']?.toString() ?? '',
    secondaryIssue: row['secondary_issue']?.toString() ?? '',
    whatWorked: row['what_worked']?.toString() ?? '',
    topCoachingPoints: stringListFromDb(row['top_coaching_points']),
    improvedExampleAnswer: row['improved_example_answer']?.toString() ?? '',
    nextAttemptTarget: row['next_attempt_target']?.toString() ?? '',
    feedbackVersion: row['feedback_version']?.toString() ?? 'v1',
  );
}

TrainingSession trainingSessionFromRow(
  Map<String, dynamic> row, {
  required PromptTemplate prompt,
  required List<SessionAttempt> attempts,
  required List<AttemptReview> reviews,
}) {
  return TrainingSession(
    id: row['id'].toString(),
    userId: row['user_id'].toString(),
    prompt: prompt,
    origin: sessionOriginFromDb(row['origin'].toString()),
    status: sessionStatusFromDb(row['status'].toString()),
    startedAt: parseDbTimestamp(row['started_at']),
    planItemId: row['plan_item_id']?.toString(),
    attempts: attempts,
    reviews: reviews,
    completedAt: row['completed_at'] == null
        ? null
        : parseDbTimestamp(row['completed_at']),
    bestAttemptNo: row['best_attempt_no'] == null
        ? null
        : asInt(row['best_attempt_no']),
    finalScore: row['final_score'] == null
        ? null
        : asDouble(row['final_score']),
    scoreDelta: row['score_delta'] == null
        ? null
        : asDouble(row['score_delta']),
  );
}

CommunicationBaseline communicationBaselineFromRow(Map<String, dynamic> row) {
  return CommunicationBaseline(
    id: row['id'].toString(),
    userId: row['user_id'].toString(),
    completedAt: parseDbTimestamp(row['completed_at']),
    overallScore: asDouble(row['overall_score']),
    assignedLevel: communicationLevelFromDb(row['assigned_level'].toString()),
    readinessScore: asDouble(row['readiness_score']),
    strengthPillars: pillarListFromDb(row['strength_pillars']),
    weakPillars: pillarListFromDb(row['weak_pillars']),
    behaviorSnapshot: behaviorMetricsFromDb(row['behavior_snapshot']),
    summaryText: row['summary_text']?.toString() ?? '',
  );
}

PillarProgressPoint pillarProgressPointFromRow(Map<String, dynamic> row) {
  return PillarProgressPoint(
    pillar: pillarFromDb(row['pillar'].toString()),
    score: asDouble(row['score']),
    recordedOn: parseDbDate(row['recorded_on']),
    weekNumber: asInt(row['week_number'], fallback: 0),
  );
}

ProgressSnapshot progressSnapshotFromRow(
  Map<String, dynamic> row, {
  required Map<Pillar, double> pillarScores,
  required List<double> overallTrend,
  required List<PillarProgressPoint> pillarHistory,
  required int missedSessions,
}) {
  return ProgressSnapshot(
    currentLevel: communicationLevelFromDb(row['current_level'].toString()),
    overallScoreEma: asDouble(row['overall_score_ema']),
    readinessScore: asDouble(row['readiness_score']),
    currentStreak: asInt(row['current_streak']),
    totalXp: asInt(row['total_xp']),
    weeklyCompletionRate: asDouble(row['weekly_completion_rate']),
    coachingAdoptionRate: asDouble(row['coaching_adoption_rate']),
    difficultyTolerance: asDouble(row['difficulty_tolerance']),
    latestRecalibrationState: recalibrationStateFromDb(
      row['latest_recalibration_state'].toString(),
    ),
    pillarScores: pillarScores,
    overallTrend: overallTrend,
    pillarHistory: pillarHistory,
    missedSessions: missedSessions,
    lastSessionAt: row['last_session_at'] == null
        ? null
        : parseDbTimestamp(row['last_session_at']),
  );
}

WeeklyRecalibration weeklyRecalibrationFromRow(Map<String, dynamic> row) {
  return WeeklyRecalibration(
    id: row['id'].toString(),
    weekNumber: asInt(row['week_number'], fallback: 1),
    classification: recalibrationStateFromDb(row['classification'].toString()),
    ruleHits: stringListFromDb(row['rule_hits']),
    changesSummary: row['changes_summary']?.toString() ?? '',
    createdAt: parseDbTimestamp(row['created_at']),
  );
}

Map<String, dynamic> sessionScoreToRow(
  SessionScore score, {
  required String attemptId,
}) {
  return {
    'session_attempt_id': attemptId,
    'overall_score': score.overallScore,
    'clarity_score': score.pillarScores[Pillar.clarity] ?? 0,
    'structure_score': score.pillarScores[Pillar.structure] ?? 0,
    'brevity_score': score.pillarScores[Pillar.brevity] ?? 0,
    'presence_score': score.pillarScores[Pillar.presence] ?? 0,
    'strategic_framing_score': score.pillarScores[Pillar.strategicFraming] ?? 0,
    'pressure_response_score': score.pillarScores[Pillar.pressureResponse] ?? 0,
    'behavior_metrics': behaviorMetricsToDb(score.behaviorMetrics),
    'scoring_version': score.scoringVersion,
  };
}

Map<String, dynamic> sessionFeedbackToRow(
  SessionFeedback feedback, {
  required String attemptId,
}) {
  return {
    'session_attempt_id': attemptId,
    'biggest_issue': feedback.biggestIssue,
    'secondary_issue': feedback.secondaryIssue,
    'what_worked': feedback.whatWorked,
    'top_coaching_points': feedback.topCoachingPoints,
    'improved_example_answer': feedback.improvedExampleAnswer,
    'next_attempt_target': feedback.nextAttemptTarget,
    'feedback_version': feedback.feedbackVersion,
  };
}
