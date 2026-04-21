import 'dart:collection';
import 'dart:math';

import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/auth/domain/auth_repository.dart';
import 'package:ceo_communication_trainer/features/profile/domain/profile_repository.dart';
import 'package:ceo_communication_trainer/features/progress/domain/progress_repository.dart';
import 'package:ceo_communication_trainer/features/training_plan/domain/adaptive_engine.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/scoring_engine.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/training_repository.dart';
import 'package:ceo_communication_trainer/services/app_service.dart';
import 'package:ceo_communication_trainer/services/demo/prompt_seed.dart';

class InMemoryAppService extends AppService
    implements
        AuthRepository,
        ProfileRepository,
        TrainingRepository,
        ProgressRepository {
  AppUser? _currentUser;
  UserProfile? _profile;
  CommunicationBaseline? _baselineSummary;
  TrainingPlan? _currentPlan;
  ProgressSnapshot? _progress;
  final List<TrainingSession> _sessions = [];
  final List<WeeklyRecalibration> _recalibrations = [];

  @override
  bool get isLoading => false;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  UserProfile? get currentProfile => _profile;

  @override
  CommunicationBaseline? get baselineSummary => _baselineSummary;

  @override
  TrainingPlan? get currentPlan => _currentPlan;

  @override
  ProgressSnapshot? get progress => _progress;

  @override
  List<PromptTemplate> get promptLibrary => List.unmodifiable(seededPrompts);

  @override
  List<PromptTemplate> get baselinePrompts =>
      List.unmodifiable(seededPrompts.take(7));

  @override
  List<TrainingSession> get sessions =>
      UnmodifiableListView(_sessions.reversed);

  @override
  List<WeeklyRecalibration> get recalibrations =>
      UnmodifiableListView(_recalibrations.reversed);

  @override
  DashboardSnapshot? get dashboard {
    final progress = _progress;
    final plan = _currentPlan;
    if (progress == null || plan == null) {
      return null;
    }

    final today = DateTime.now();
    final todayItems = plan.currentVersion.items
        .where((item) => _isSameDay(item.scheduledFor, today))
        .toList();
    final upcomingItems = plan.currentVersion.items
        .where(
          (item) =>
              item.status == PlanItemStatus.scheduled &&
              item.scheduledFor.isAfter(
                today.subtract(const Duration(days: 1)),
              ),
        )
        .take(5)
        .toList();
    final weakestPillar = progress.pillarScores.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
    final latestImprovement = _sessions.isEmpty
        ? 0.0
        : (_sessions.first.scoreDelta ?? 0.0);

    return DashboardSnapshot(
      currentLevel: progress.currentLevel,
      readinessScore: progress.readinessScore,
      streak: progress.currentStreak,
      thisWeeksStatus: progress.latestRecalibrationState,
      todayItems: todayItems,
      upcomingItems: upcomingItems,
      weakestPillar: weakestPillar,
      latestImprovement: latestImprovement,
      progress: progress,
    );
  }

  @override
  Future<void> signIn(String email, String password, {bool isSignUp = false}) async {
    _currentUser = AppUser(
      id: 'user-${email.hashCode.abs()}',
      email: email.trim().toLowerCase(),
    );
    _profile ??= UserProfile(
      userId: _currentUser!.id,
      displayName: '',
      roleTitle: '',
      seniorityBand: SeniorityBand.manager,
      industry: '',
      timezone: DateTime.now().timeZoneName,
      weeklyGoalCount: 5,
      communicationContexts: const [],
      goals: const [],
      microphoneConsent: false,
      preferredResponseMode: ResponseMode.typed,
    );
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _profile = null;
    _baselineSummary = null;
    _currentPlan = null;
    _progress = null;
    _sessions.clear();
    _recalibrations.clear();
    notifyListeners();
  }

  @override
  Future<void> saveProfile({
    required String displayName,
    required String roleTitle,
    required SeniorityBand seniorityBand,
    required String industry,
    required String timezone,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    _profile =
        (_profile ??
                UserProfile(
                  userId: user.id,
                  displayName: displayName,
                  roleTitle: roleTitle,
                  seniorityBand: seniorityBand,
                  industry: industry,
                  timezone: timezone,
                  weeklyGoalCount: 5,
                  communicationContexts: const [],
                  goals: const [],
                  microphoneConsent: false,
                  preferredResponseMode: ResponseMode.typed,
                ))
            .copyWith(
              displayName: displayName,
              roleTitle: roleTitle,
              seniorityBand: seniorityBand,
              industry: industry,
              timezone: timezone,
            );
    notifyListeners();
  }

  @override
  Future<void> completeOnboarding({
    required int weeklyGoalCount,
    required List<String> communicationContexts,
    required List<String> goals,
    required bool microphoneConsent,
    required ResponseMode preferredResponseMode,
  }) async {
    final profile = _profile;
    if (profile == null) return;

    _profile = profile.copyWith(
      weeklyGoalCount: weeklyGoalCount,
      communicationContexts: communicationContexts,
      goals: goals,
      microphoneConsent: microphoneConsent,
      preferredResponseMode: preferredResponseMode,
      onboardingCompletedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<TrainingSession> openBaselineSession(int index) async {
    final existing = _sessions
        .where(
          (session) =>
              session.origin == SessionOrigin.baseline &&
              session.prompt.id == baselinePrompts[index].id &&
              !session.isCompleted,
        )
        .firstOrNull;
    if (existing != null) {
      return existing;
    }

    return _createSession(
      prompt: baselinePrompts[index],
      origin: SessionOrigin.baseline,
    );
  }

  @override
  Future<TrainingSession> openPlanSession(String planItemId) async {
    final existing = _sessions
        .where(
          (session) => session.planItemId == planItemId && !session.isCompleted,
        )
        .firstOrNull;
    if (existing != null) {
      return existing;
    }

    final planItem = _currentPlan?.currentVersion.items.firstWhere(
      (item) => item.id == planItemId,
    );
    final prompt = promptLibrary.firstWhere(
      (item) => item.id == planItem!.promptId,
    );
    return _createSession(
      prompt: prompt,
      origin: SessionOrigin.dailyPlan,
      planItemId: planItemId,
    );
  }

  @override
  Future<TrainingSession> openRetrySession(String sessionId) async {
    return _sessions.firstWhere((session) => session.id == sessionId);
  }

  TrainingSession _createSession({
    required PromptTemplate prompt,
    required SessionOrigin origin,
    String? planItemId,
  }) {
    final session = TrainingSession(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}-${prompt.id}',
      userId: _currentUser!.id,
      prompt: prompt,
      origin: origin,
      status: SessionStatus.inProgress,
      startedAt: DateTime.now(),
      planItemId: planItemId,
      attempts: const [],
      reviews: const [],
    );
    _sessions.insert(0, session);
    notifyListeners();
    return session;
  }

  @override
  Future<TrainingSession> submitAttempt({
    required String sessionId,
    required String responseText,
    required ResponseMode responseMode,
  }) async {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) {
      throw StateError('Session not found.');
    }
    final session = _sessions[index];
    final nextAttemptNo = session.attempts.length + 1;
    final wordCount = _wordCount(responseText);
    final estimatedDuration = max(
      session.prompt.targetDurationSec - 5,
      (wordCount / 140 * 60).round(),
    );
    final attempt = SessionAttempt(
      id: 'attempt-$nextAttemptNo-$sessionId',
      attemptNo: nextAttemptNo,
      responseMode: responseMode,
      responseText: responseText.trim(),
      durationSeconds: estimatedDuration,
      wordCount: wordCount,
      submittedAt: DateTime.now(),
    );
    final scored = ScoringEngine.evaluate(
      prompt: session.prompt,
      responseText: responseText,
      responseMode: responseMode,
      previousAttempt: session.attempts.isEmpty ? null : session.attempts.last,
    );

    final updated = session.copyWith(
      attempts: [...session.attempts, attempt],
      reviews: [
        ...session.reviews,
        AttemptReview(score: scored.score, feedback: scored.feedback),
      ],
    );
    _sessions[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<void> finalizeSession(String sessionId) async {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) return;

    final session = _sessions[index];
    if (session.reviews.isEmpty) return;

    final bestReview = session.reviews.reduce(
      (current, next) => current.score.overallScore >= next.score.overallScore
          ? current
          : next,
    );
    final bestAttemptIndex = session.reviews.indexOf(bestReview);
    final scoreDelta = session.reviews.length > 1
        ? session.reviews.last.score.overallScore -
              session.reviews.first.score.overallScore
        : 0.0;

    final completed = session.copyWith(
      status: SessionStatus.completed,
      completedAt: DateTime.now(),
      bestAttemptNo: bestAttemptIndex + 1,
      finalScore: bestReview.score.overallScore,
      scoreDelta: scoreDelta,
    );
    _sessions[index] = completed;

    if (completed.planItemId != null && _currentPlan != null) {
      final items = _currentPlan!.currentVersion.items.map((item) {
        if (item.id == completed.planItemId) {
          return item.copyWith(status: PlanItemStatus.completed);
        }
        return item;
      }).toList();
      final version = TrainingPlanVersion(
        id: _currentPlan!.currentVersion.id,
        versionNumber: _currentPlan!.currentVersion.versionNumber,
        source: _currentPlan!.currentVersion.source,
        generatedAt: _currentPlan!.currentVersion.generatedAt,
        rationaleText: _currentPlan!.currentVersion.rationaleText,
        items: items,
      );
      _currentPlan = _currentPlan!.copyWith(currentVersion: version);
    }

    if (_baselineSummary == null && _allBaselineSessionsCompleted()) {
      _completeBaselineAndGeneratePlan();
    } else if (_baselineSummary != null) {
      _refreshProgressFromCompletedSessions();
    }

    notifyListeners();
  }

  bool _allBaselineSessionsCompleted() {
    final completedBaselineIds = _sessions
        .where(
          (session) =>
              session.origin == SessionOrigin.baseline && session.isCompleted,
        )
        .map((session) => session.prompt.id)
        .toSet();
    return baselinePrompts.every(
      (prompt) => completedBaselineIds.contains(prompt.id),
    );
  }

  void _completeBaselineAndGeneratePlan() {
    final completed = _sessions
        .where(
          (session) =>
              session.origin == SessionOrigin.baseline && session.isCompleted,
        )
        .toList();
    if (completed.length < baselinePrompts.length ||
        _profile == null ||
        _currentUser == null) {
      return;
    }

    final pillarTotals = <Pillar, double>{
      for (final pillar in Pillar.values) pillar: 0,
    };
    var overall = 0.0;
    var directAnswer = 0.0;
    var bluf = 0.0;
    var structureRate = 0.0;
    var avgWords = 0.0;

    for (final session in completed) {
      final review = session.reviews[session.bestAttemptNo! - 1];
      overall += session.finalScore ?? review.score.overallScore;
      directAnswer += review.score.behaviorMetrics.directAnswerRate;
      bluf += review.score.behaviorMetrics.blufUsageRate;
      structureRate +=
          review.score.behaviorMetrics.cleanThreePointStructureRate;
      avgWords += review.score.behaviorMetrics.averageResponseLengthWords;

      for (final pillar in Pillar.values) {
        pillarTotals[pillar] =
            (pillarTotals[pillar] ?? 0) +
            (review.score.pillarScores[pillar] ?? 0);
      }
    }

    final averages = <Pillar, double>{
      for (final entry in pillarTotals.entries)
        entry.key: entry.value / completed.length,
    };
    final overallAverage = overall / completed.length;
    final behaviorSnapshot = BehaviorMetrics(
      directAnswerRate: directAnswer / completed.length,
      blufUsageRate: bluf / completed.length,
      cleanThreePointStructureRate: structureRate / completed.length,
      averageResponseLengthWords: avgWords / completed.length,
      coachingAdoptionRate: 0.5,
      consistency: 0.7,
      difficultyTolerance: 0.55,
    );
    final level = AdaptiveEngine.assignLevel(
      pillarScores: averages,
      behavior: behaviorSnapshot,
      overall: overallAverage,
      latestState: RecalibrationState.stable,
    );
    final readiness = AdaptiveEngine.computeReadiness(
      normalizedOverall: overallAverage / 100,
      consistency: 0.7,
      coachingAdoption: 0.5,
      difficultyTolerance: 0.55,
    );
    final ranked = averages.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    _baselineSummary = CommunicationBaseline(
      id: 'baseline-${_currentUser!.id}',
      userId: _currentUser!.id,
      completedAt: DateTime.now(),
      overallScore: overallAverage,
      assignedLevel: level,
      readinessScore: readiness,
      strengthPillars: ranked.reversed
          .take(2)
          .map((entry) => entry.key)
          .toList(),
      weakPillars: ranked.take(2).map((entry) => entry.key).toList(),
      behaviorSnapshot: behaviorSnapshot,
      summaryText:
          'You have a credible foundation, but the biggest upside still comes from faster answers and cleaner structure.',
    );
    _profile = _profile?.copyWith(baselineCompletedAt: DateTime.now());
    _currentPlan = AdaptiveEngine.generateInitialPlan(
      userId: _currentUser!.id,
      baseline: _baselineSummary!,
      profile: _profile!,
      promptLibrary: promptLibrary,
    );
    _progress = ProgressSnapshot(
      currentLevel: level,
      overallScoreEma: overallAverage,
      readinessScore: readiness,
      currentStreak: 1,
      totalXp: completed.length * 10,
      weeklyCompletionRate: 1,
      coachingAdoptionRate: 0.5,
      difficultyTolerance: 0.55,
      latestRecalibrationState: RecalibrationState.stable,
      pillarScores: averages,
      overallTrend: completed
          .map((session) => session.finalScore ?? 0)
          .toList(),
      pillarHistory: [
        for (final entry in averages.entries)
          PillarProgressPoint(
            pillar: entry.key,
            score: entry.value,
            recordedOn: DateTime.now(),
            weekNumber: 0,
          ),
      ],
      missedSessions: 0,
      lastSessionAt: DateTime.now(),
    );
  }

  void _refreshProgressFromCompletedSessions() {
    final progress = _progress;
    if (progress == null) return;

    final completed = _sessions
        .where((session) => session.isCompleted)
        .toList();
    final finalSessions = completed
        .map((session) => session.reviews[(session.bestAttemptNo ?? 1) - 1])
        .toList();
    if (finalSessions.isEmpty) return;

    final emaScores = Map<Pillar, double>.from(progress.pillarScores);
    final latestReview = finalSessions.last;
    latestReview.score.pillarScores.forEach((pillar, score) {
      final previous = emaScores[pillar] ?? score;
      emaScores[pillar] = (previous * 0.75) + (score * 0.25);
    });

    final overall = AdaptiveEngine.computeOverallFromPillars(emaScores);
    final coachingAdoptionRate = _coachingAdoptionRate();
    final completionRate = _weeklyCompletionRate();
    final difficultyTolerance = _difficultyTolerance();
    final readiness = AdaptiveEngine.computeReadiness(
      normalizedOverall: overall / 100,
      consistency: completionRate,
      coachingAdoption: coachingAdoptionRate,
      difficultyTolerance: difficultyTolerance,
    );
    final level = AdaptiveEngine.assignLevel(
      pillarScores: emaScores,
      behavior: latestReview.score.behaviorMetrics.copyWith(
        coachingAdoptionRate: coachingAdoptionRate,
        consistency: completionRate,
        difficultyTolerance: difficultyTolerance,
      ),
      overall: overall,
      latestState: progress.latestRecalibrationState,
    );

    final trend = [...progress.overallTrend, overall];
    final history = [
      ...progress.pillarHistory,
      for (final entry in emaScores.entries)
        PillarProgressPoint(
          pillar: entry.key,
          score: entry.value,
          recordedOn: DateTime.now(),
          weekNumber: _currentWeekNumber(),
        ),
    ];

    _progress = progress.copyWith(
      currentLevel: level,
      overallScoreEma: overall,
      readinessScore: readiness,
      currentStreak: _currentStreak(),
      totalXp: _totalXp(),
      weeklyCompletionRate: completionRate,
      coachingAdoptionRate: coachingAdoptionRate,
      difficultyTolerance: difficultyTolerance,
      pillarScores: emaScores,
      overallTrend: trend.take(8).toList(),
      pillarHistory: history,
      lastSessionAt: DateTime.now(),
    );
  }

  @override
  Future<WeeklyRecalibration> generateWeeklyRecalibration() async {
    final progress = _progress;
    if (progress == null) {
      throw StateError('Progress has not been initialized.');
    }

    final recalibration = AdaptiveEngine.generateWeeklyRecalibration(
      weekNumber: _currentWeekNumber(),
      progress: progress,
      sessions: _sessions,
    );
    _recalibrations.insert(0, recalibration);
    _progress = progress.copyWith(
      latestRecalibrationState: recalibration.classification,
    );
    notifyListeners();
    return recalibration;
  }

  double _coachingAdoptionRate() {
    final completed = _sessions.where(
      (session) => session.isCompleted && session.reviews.length > 1,
    );
    if (completed.isEmpty) return 0.5;
    final improved = completed
        .where((session) => (session.scoreDelta ?? 0) >= 3)
        .length;
    return improved / completed.length;
  }

  double _weeklyCompletionRate() {
    final plan = _currentPlan;
    if (plan == null) return 1;

    final thisWeek = plan.currentVersion.items
        .where((item) => item.weekNumber == _currentWeekNumber())
        .toList();
    if (thisWeek.isEmpty) return 1;
    final completed = thisWeek
        .where((item) => item.status == PlanItemStatus.completed)
        .length;
    return completed / thisWeek.length;
  }

  double _difficultyTolerance() {
    final completed = _sessions
        .where(
          (session) =>
              session.isCompleted && session.origin == SessionOrigin.dailyPlan,
        )
        .toList();
    if (completed.isEmpty) return 0.55;
    final highestTier = completed
        .map((session) => session.prompt.difficultyTier)
        .fold<int>(1, max);
    final atHighest = completed
        .where((session) => session.prompt.difficultyTier == highestTier)
        .toList();
    if (atHighest.isEmpty) return 0.55;
    final successful = atHighest
        .where((session) => (session.finalScore ?? 0) >= 65)
        .length;
    return successful / atHighest.length;
  }

  int _currentStreak() {
    final completed =
        _sessions
            .where(
              (session) => session.isCompleted && session.completedAt != null,
            )
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    if (completed.isEmpty) return 0;

    var streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final found = completed.any(
        (session) => _isSameDay(session.completedAt!, cursor),
      );
      if (!found) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return max(streak, 1);
  }

  int _totalXp() {
    var xp = _sessions.where((session) => session.isCompleted).length * 10;
    xp +=
        _sessions.where((session) => (session.scoreDelta ?? 0) >= 3).length * 5;
    return xp;
  }

  int _currentWeekNumber() {
    final plan = _currentPlan;
    if (plan == null) return 1;
    return (((DateTime.now().difference(plan.startDate).inDays) ~/ 7) + 1)
        .clamp(1, 10);
  }

  int _wordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
