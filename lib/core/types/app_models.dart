import 'package:ceo_communication_trainer/core/types/app_types.dart';

class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.roleTitle,
    required this.seniorityBand,
    required this.industry,
    required this.timezone,
    required this.weeklyGoalCount,
    required this.communicationContexts,
    required this.goals,
    required this.microphoneConsent,
    required this.preferredResponseMode,
    this.dailyReminderTime = '',
    this.onboardingCompletedAt,
    this.baselineCompletedAt,
  });

  final String userId;
  final String displayName;
  final String roleTitle;
  final SeniorityBand seniorityBand;
  final String industry;
  final String timezone;
  final int weeklyGoalCount;
  final List<String> communicationContexts;
  final List<String> goals;
  final bool microphoneConsent;
  final ResponseMode preferredResponseMode;
  final String dailyReminderTime;
  final DateTime? onboardingCompletedAt;
  final DateTime? baselineCompletedAt;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;
  bool get hasCompletedBaseline => baselineCompletedAt != null;

  UserProfile copyWith({
    String? displayName,
    String? roleTitle,
    SeniorityBand? seniorityBand,
    String? industry,
    String? timezone,
    int? weeklyGoalCount,
    List<String>? communicationContexts,
    List<String>? goals,
    bool? microphoneConsent,
    ResponseMode? preferredResponseMode,
    String? dailyReminderTime,
    DateTime? onboardingCompletedAt,
    DateTime? baselineCompletedAt,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      roleTitle: roleTitle ?? this.roleTitle,
      seniorityBand: seniorityBand ?? this.seniorityBand,
      industry: industry ?? this.industry,
      timezone: timezone ?? this.timezone,
      weeklyGoalCount: weeklyGoalCount ?? this.weeklyGoalCount,
      communicationContexts:
          communicationContexts ?? this.communicationContexts,
      goals: goals ?? this.goals,
      microphoneConsent: microphoneConsent ?? this.microphoneConsent,
      preferredResponseMode:
          preferredResponseMode ?? this.preferredResponseMode,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      baselineCompletedAt: baselineCompletedAt ?? this.baselineCompletedAt,
    );
  }
}

class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.slug,
    required this.title,
    required this.category,
    required this.difficultyTier,
    required this.scenarioContext,
    required this.promptText,
    required this.targetDurationSec,
    required this.targetWordRangeMin,
    required this.targetWordRangeMax,
    required this.pillarWeights,
    required this.behaviorTargets,
  });

  final String id;
  final String slug;
  final String title;
  final PromptCategory category;
  final int difficultyTier;
  final String scenarioContext;
  final String promptText;
  final int targetDurationSec;
  final int targetWordRangeMin;
  final int targetWordRangeMax;
  final Map<Pillar, double> pillarWeights;
  final Map<String, double> behaviorTargets;

  List<Pillar> get activePillars => pillarWeights.keys.toList();
}

class PlanItem {
  const PlanItem({
    required this.id,
    required this.promptId,
    required this.weekNumber,
    required this.dayNumber,
    required this.sequenceNumber,
    required this.scheduledFor,
    required this.drillType,
    required this.focusPillars,
    required this.difficultyTier,
    required this.targetMetrics,
    required this.status,
  });

  final String id;
  final String promptId;
  final int weekNumber;
  final int dayNumber;
  final int sequenceNumber;
  final DateTime scheduledFor;
  final String drillType;
  final List<Pillar> focusPillars;
  final int difficultyTier;
  final Map<String, double> targetMetrics;
  final PlanItemStatus status;

  PlanItem copyWith({PlanItemStatus? status, DateTime? scheduledFor}) {
    return PlanItem(
      id: id,
      promptId: promptId,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
      sequenceNumber: sequenceNumber,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      drillType: drillType,
      focusPillars: focusPillars,
      difficultyTier: difficultyTier,
      targetMetrics: targetMetrics,
      status: status ?? this.status,
    );
  }
}

class TrainingPlanVersion {
  const TrainingPlanVersion({
    required this.id,
    required this.versionNumber,
    required this.source,
    required this.generatedAt,
    required this.rationaleText,
    required this.items,
  });

  final String id;
  final int versionNumber;
  final String source;
  final DateTime generatedAt;
  final String rationaleText;
  final List<PlanItem> items;
}

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.targetEndDate,
    required this.status,
    required this.currentVersion,
    required this.previousVersions,
  });

  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime targetEndDate;
  final String status;
  final TrainingPlanVersion currentVersion;
  final List<TrainingPlanVersion> previousVersions;

  TrainingPlan copyWith({
    TrainingPlanVersion? currentVersion,
    List<TrainingPlanVersion>? previousVersions,
    String? status,
  }) {
    return TrainingPlan(
      id: id,
      userId: userId,
      startDate: startDate,
      targetEndDate: targetEndDate,
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      previousVersions: previousVersions ?? this.previousVersions,
    );
  }
}

class WeeklySessionEvaluation {
  const WeeklySessionEvaluation({
    required this.sessionId,
    required this.aiScore,
    required this.keyObservations,
  });

  final String sessionId;
  final double aiScore;
  final List<String> keyObservations;
}

class WeeklyDrillLesson {
  const WeeklyDrillLesson({
    required this.planItemId,
    required this.lessonTitle,
    required this.lessonBody,
    required this.goodExample,
    required this.exampleAnalysis,
    required this.userDevelopmentFocus,
    required this.preDrillChecklist,
    this.drillPurpose = '',
    this.successSignals = const [],
    this.aiScenarioContext,
    this.aiPromptText,
  });

  final String planItemId;
  final String lessonTitle;
  final String lessonBody;
  final String goodExample;
  final String exampleAnalysis;
  final String userDevelopmentFocus;
  final List<String> preDrillChecklist;
  final String drillPurpose;
  final List<String> successSignals;
  final String? aiScenarioContext;
  final String? aiPromptText;

  WeeklyDrillLesson copyWith({
    String? lessonTitle,
    String? lessonBody,
    String? goodExample,
    String? exampleAnalysis,
    String? userDevelopmentFocus,
    List<String>? preDrillChecklist,
    String? drillPurpose,
    List<String>? successSignals,
    String? aiScenarioContext,
    String? aiPromptText,
  }) {
    return WeeklyDrillLesson(
      planItemId: planItemId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      lessonBody: lessonBody ?? this.lessonBody,
      goodExample: goodExample ?? this.goodExample,
      exampleAnalysis: exampleAnalysis ?? this.exampleAnalysis,
      userDevelopmentFocus: userDevelopmentFocus ?? this.userDevelopmentFocus,
      preDrillChecklist: preDrillChecklist ?? this.preDrillChecklist,
      drillPurpose: drillPurpose ?? this.drillPurpose,
      successSignals: successSignals ?? this.successSignals,
      aiScenarioContext: aiScenarioContext ?? this.aiScenarioContext,
      aiPromptText: aiPromptText ?? this.aiPromptText,
    );
  }
}

class WeeklyLessonPacket {
  const WeeklyLessonPacket({
    required this.id,
    required this.planVersionId,
    required this.weekNumber,
    required this.weeklyObjective,
    required this.developmentSummary,
    required this.rawImportText,
    required this.drills,
    required this.createdAt,
    required this.updatedAt,
    this.previousWeekAnalysis = '',
    this.previousWeekEvaluations = const [],
  });

  final String id;
  final String planVersionId;
  final int weekNumber;
  final String weeklyObjective;
  final String developmentSummary;
  final String rawImportText;
  final List<WeeklyDrillLesson> drills;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String previousWeekAnalysis;
  final List<WeeklySessionEvaluation> previousWeekEvaluations;

  WeeklyDrillLesson? lessonForPlanItem(String planItemId) {
    for (final lesson in drills) {
      if (lesson.planItemId == planItemId) {
        return lesson;
      }
    }
    return null;
  }

  WeeklyLessonPacket copyWith({
    String? weeklyObjective,
    String? developmentSummary,
    String? rawImportText,
    List<WeeklyDrillLesson>? drills,
    DateTime? updatedAt,
    String? previousWeekAnalysis,
    List<WeeklySessionEvaluation>? previousWeekEvaluations,
  }) {
    return WeeklyLessonPacket(
      id: id,
      planVersionId: planVersionId,
      weekNumber: weekNumber,
      weeklyObjective: weeklyObjective ?? this.weeklyObjective,
      developmentSummary: developmentSummary ?? this.developmentSummary,
      rawImportText: rawImportText ?? this.rawImportText,
      drills: drills ?? this.drills,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      previousWeekAnalysis: previousWeekAnalysis ?? this.previousWeekAnalysis,
      previousWeekEvaluations:
          previousWeekEvaluations ?? this.previousWeekEvaluations,
    );
  }
}

class BehaviorMetrics {
  const BehaviorMetrics({
    required this.directAnswerRate,
    required this.blufUsageRate,
    required this.cleanThreePointStructureRate,
    required this.averageResponseLengthWords,
    this.fillerWordsPerMinute,
    this.wordsPerMinute,
    this.retryCount = 0,
    this.coachingAdoptionRate = 0,
    this.consistency = 0,
    this.missedSessions = 0,
    this.difficultyTolerance = 0,
  });

  final double directAnswerRate;
  final double blufUsageRate;
  final double cleanThreePointStructureRate;
  final double averageResponseLengthWords;
  final double? fillerWordsPerMinute;
  final double? wordsPerMinute;
  final int retryCount;
  final double coachingAdoptionRate;
  final double consistency;
  final int missedSessions;
  final double difficultyTolerance;

  BehaviorMetrics copyWith({
    double? directAnswerRate,
    double? blufUsageRate,
    double? cleanThreePointStructureRate,
    double? averageResponseLengthWords,
    double? fillerWordsPerMinute,
    double? wordsPerMinute,
    int? retryCount,
    double? coachingAdoptionRate,
    double? consistency,
    int? missedSessions,
    double? difficultyTolerance,
  }) {
    return BehaviorMetrics(
      directAnswerRate: directAnswerRate ?? this.directAnswerRate,
      blufUsageRate: blufUsageRate ?? this.blufUsageRate,
      cleanThreePointStructureRate:
          cleanThreePointStructureRate ?? this.cleanThreePointStructureRate,
      averageResponseLengthWords:
          averageResponseLengthWords ?? this.averageResponseLengthWords,
      fillerWordsPerMinute: fillerWordsPerMinute ?? this.fillerWordsPerMinute,
      wordsPerMinute: wordsPerMinute ?? this.wordsPerMinute,
      retryCount: retryCount ?? this.retryCount,
      coachingAdoptionRate: coachingAdoptionRate ?? this.coachingAdoptionRate,
      consistency: consistency ?? this.consistency,
      missedSessions: missedSessions ?? this.missedSessions,
      difficultyTolerance: difficultyTolerance ?? this.difficultyTolerance,
    );
  }
}

class SessionScore {
  const SessionScore({
    required this.overallScore,
    required this.pillarScores,
    required this.behaviorMetrics,
    this.scoringVersion = 'local-v1',
  });

  final double overallScore;
  final Map<Pillar, double> pillarScores;
  final BehaviorMetrics behaviorMetrics;
  final String scoringVersion;
}

class SessionFeedback {
  const SessionFeedback({
    required this.biggestIssue,
    required this.secondaryIssue,
    required this.whatWorked,
    required this.topCoachingPoints,
    required this.improvedExampleAnswer,
    required this.nextAttemptTarget,
    this.feedbackVersion = 'local-v1',
  });

  final String biggestIssue;
  final String secondaryIssue;
  final String whatWorked;
  final List<String> topCoachingPoints;
  final String improvedExampleAnswer;
  final String nextAttemptTarget;
  final String feedbackVersion;
}

class AttemptReview {
  const AttemptReview({required this.score, required this.feedback});

  final SessionScore score;
  final SessionFeedback feedback;
}

class SessionAttempt {
  const SessionAttempt({
    required this.id,
    required this.attemptNo,
    required this.responseMode,
    required this.responseText,
    required this.durationSeconds,
    required this.wordCount,
    required this.submittedAt,
  });

  final String id;
  final int attemptNo;
  final ResponseMode responseMode;
  final String responseText;
  final int durationSeconds;
  final int wordCount;
  final DateTime submittedAt;
}

class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.origin,
    required this.status,
    required this.startedAt,
    required this.attempts,
    required this.reviews,
    this.planItemId,
    this.completedAt,
    this.bestAttemptNo,
    this.finalScore,
    this.scoreDelta,
  });

  final String id;
  final String userId;
  final PromptTemplate prompt;
  final SessionOrigin origin;
  final SessionStatus status;
  final DateTime startedAt;
  final String? planItemId;
  final List<SessionAttempt> attempts;
  final List<AttemptReview> reviews;
  final DateTime? completedAt;
  final int? bestAttemptNo;
  final double? finalScore;
  final double? scoreDelta;

  bool get isCompleted => status == SessionStatus.completed;

  TrainingSession copyWith({
    SessionStatus? status,
    List<SessionAttempt>? attempts,
    List<AttemptReview>? reviews,
    DateTime? completedAt,
    int? bestAttemptNo,
    double? finalScore,
    double? scoreDelta,
  }) {
    return TrainingSession(
      id: id,
      userId: userId,
      prompt: prompt,
      origin: origin,
      status: status ?? this.status,
      startedAt: startedAt,
      planItemId: planItemId,
      attempts: attempts ?? this.attempts,
      reviews: reviews ?? this.reviews,
      completedAt: completedAt ?? this.completedAt,
      bestAttemptNo: bestAttemptNo ?? this.bestAttemptNo,
      finalScore: finalScore ?? this.finalScore,
      scoreDelta: scoreDelta ?? this.scoreDelta,
    );
  }
}

class CommunicationBaseline {
  const CommunicationBaseline({
    required this.id,
    required this.userId,
    required this.completedAt,
    required this.overallScore,
    required this.assignedLevel,
    required this.readinessScore,
    required this.strengthPillars,
    required this.weakPillars,
    required this.behaviorSnapshot,
    required this.summaryText,
  });

  final String id;
  final String userId;
  final DateTime completedAt;
  final double overallScore;
  final CommunicationLevel assignedLevel;
  final double readinessScore;
  final List<Pillar> strengthPillars;
  final List<Pillar> weakPillars;
  final BehaviorMetrics behaviorSnapshot;
  final String summaryText;
}

class PillarProgressPoint {
  const PillarProgressPoint({
    required this.pillar,
    required this.score,
    required this.recordedOn,
    required this.weekNumber,
  });

  final Pillar pillar;
  final double score;
  final DateTime recordedOn;
  final int weekNumber;
}

class WeeklyRecalibration {
  const WeeklyRecalibration({
    required this.id,
    required this.weekNumber,
    required this.classification,
    required this.ruleHits,
    required this.changesSummary,
    required this.createdAt,
  });

  final String id;
  final int weekNumber;
  final RecalibrationState classification;
  final List<String> ruleHits;
  final String changesSummary;
  final DateTime createdAt;
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.currentLevel,
    required this.overallScoreEma,
    required this.readinessScore,
    required this.currentStreak,
    required this.totalXp,
    required this.weeklyCompletionRate,
    required this.coachingAdoptionRate,
    required this.difficultyTolerance,
    required this.latestRecalibrationState,
    required this.pillarScores,
    required this.overallTrend,
    required this.pillarHistory,
    required this.missedSessions,
    this.lastSessionAt,
  });

  final CommunicationLevel currentLevel;
  final double overallScoreEma;
  final double readinessScore;
  final int currentStreak;
  final int totalXp;
  final double weeklyCompletionRate;
  final double coachingAdoptionRate;
  final double difficultyTolerance;
  final RecalibrationState latestRecalibrationState;
  final Map<Pillar, double> pillarScores;
  final List<double> overallTrend;
  final List<PillarProgressPoint> pillarHistory;
  final int missedSessions;
  final DateTime? lastSessionAt;

  ProgressSnapshot copyWith({
    CommunicationLevel? currentLevel,
    double? overallScoreEma,
    double? readinessScore,
    int? currentStreak,
    int? totalXp,
    double? weeklyCompletionRate,
    double? coachingAdoptionRate,
    double? difficultyTolerance,
    RecalibrationState? latestRecalibrationState,
    Map<Pillar, double>? pillarScores,
    List<double>? overallTrend,
    List<PillarProgressPoint>? pillarHistory,
    int? missedSessions,
    DateTime? lastSessionAt,
  }) {
    return ProgressSnapshot(
      currentLevel: currentLevel ?? this.currentLevel,
      overallScoreEma: overallScoreEma ?? this.overallScoreEma,
      readinessScore: readinessScore ?? this.readinessScore,
      currentStreak: currentStreak ?? this.currentStreak,
      totalXp: totalXp ?? this.totalXp,
      weeklyCompletionRate: weeklyCompletionRate ?? this.weeklyCompletionRate,
      coachingAdoptionRate: coachingAdoptionRate ?? this.coachingAdoptionRate,
      difficultyTolerance: difficultyTolerance ?? this.difficultyTolerance,
      latestRecalibrationState:
          latestRecalibrationState ?? this.latestRecalibrationState,
      pillarScores: pillarScores ?? this.pillarScores,
      overallTrend: overallTrend ?? this.overallTrend,
      pillarHistory: pillarHistory ?? this.pillarHistory,
      missedSessions: missedSessions ?? this.missedSessions,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.currentLevel,
    required this.readinessScore,
    required this.streak,
    required this.thisWeeksStatus,
    required this.todayItems,
    required this.upcomingItems,
    required this.weakestPillar,
    required this.latestImprovement,
    required this.progress,
  });

  final CommunicationLevel currentLevel;
  final double readinessScore;
  final int streak;
  final RecalibrationState thisWeeksStatus;
  final List<PlanItem> todayItems;
  final List<PlanItem> upcomingItems;
  final Pillar weakestPillar;
  final double latestImprovement;
  final ProgressSnapshot progress;
}
