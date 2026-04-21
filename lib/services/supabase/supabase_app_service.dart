import 'dart:async';
import 'dart:math';

import 'package:ceo_communication_trainer/app/bootstrap/app_config.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_plan/domain/adaptive_engine.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/scoring_engine.dart';
import 'package:ceo_communication_trainer/services/app_service.dart';
import 'package:ceo_communication_trainer/services/demo/prompt_seed.dart';
import 'package:ceo_communication_trainer/services/supabase/supabase_mappers.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAppService extends AppService {
  SupabaseAppService({
    required SupabaseClient client,
    required AppConfig config,
  }) : _client = client {
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      unawaited(_syncWithAuthSession());
    });
    unawaited(_syncWithAuthSession());
  }

  final SupabaseClient _client;

  StreamSubscription<AuthState>? _authSubscription;
  final List<TrainingSession> _sessions = [];
  final List<WeeklyRecalibration> _recalibrations = [];
  final List<PromptTemplate> _promptLibrary = [];

  AppUser? _currentUser;
  UserProfile? _profile;
  CommunicationBaseline? _baselineSummary;
  TrainingPlan? _currentPlan;
  ProgressSnapshot? _progress;
  bool _isLoading = true;
  bool _disposed = false;
  int _syncEpoch = 0;

  static final List<String> _baselinePromptOrder = seededPrompts
      .where((prompt) => prompt.slug.startsWith('baseline-'))
      .map((prompt) => prompt.slug)
      .toList();

  @override
  bool get isLoading => _isLoading;

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
  List<PromptTemplate> get promptLibrary => List.unmodifiable(_promptLibrary);

  @override
  List<PromptTemplate> get baselinePrompts {
    final prompts = _promptLibrary
        .where((prompt) => prompt.slug.startsWith('baseline-'))
        .toList()
      ..sort((a, b) {
        final aIndex = _baselinePromptOrder.indexOf(a.slug);
        final bIndex = _baselinePromptOrder.indexOf(b.slug);
        return (aIndex == -1 ? 999 : aIndex).compareTo(
          bIndex == -1 ? 999 : bIndex,
        );
      });
    return List.unmodifiable(prompts);
  }

  @override
  List<TrainingSession> get sessions => List.unmodifiable(_sessions.reversed);

  @override
  List<WeeklyRecalibration> get recalibrations =>
      List.unmodifiable(_recalibrations.reversed);

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
    final normalizedEmail = email.trim().toLowerCase();
    if (isSignUp) {
      await _client.auth.signUp(email: normalizedEmail, password: password);
    } else {
      await _client.auth.signInWithPassword(email: normalizedEmail, password: password);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> saveProfile({
    required String displayName,
    required String roleTitle,
    required SeniorityBand seniorityBand,
    required String industry,
    required String timezone,
  }) async {
    debugPrint('saveProfile: called for user ${_currentUser?.id}');
    final user = _requireCurrentUser();
    debugPrint('saveProfile: upserting...');
    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
      'role_title': roleTitle,
      'seniority_band': seniorityBandToDb(seniorityBand),
      'industry': industry,
      'timezone': timezone,
      'weekly_goal_count': _profile?.weeklyGoalCount ?? 5,
      'communication_contexts': _profile?.communicationContexts ?? <String>[],
      'goals': _profile?.goals ?? <String>[],
      'microphone_consent': _profile?.microphoneConsent ?? false,
      'preferred_response_mode': responseModeToDb(
        _profile?.preferredResponseMode ?? ResponseMode.typed,
      ),
      'onboarding_completed_at': _profile?.onboardingCompletedAt
          ?.toUtc()
          .toIso8601String(),
      'baseline_completed_at': _profile?.baselineCompletedAt
          ?.toUtc()
          .toIso8601String(),
    }, onConflict: 'id');

    // Cancel any in-flight sync so it doesn't overwrite our fresh local state.
    _syncEpoch++;
    _profile =
        (_profile ??
                UserProfile(
                  userId: user.id,
                  displayName: '',
                  roleTitle: '',
                  seniorityBand: SeniorityBand.manager,
                  industry: '',
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
    _publish();
  }

  @override
  Future<void> completeOnboarding({
    required int weeklyGoalCount,
    required List<String> communicationContexts,
    required List<String> goals,
    required bool microphoneConsent,
    required ResponseMode preferredResponseMode,
  }) async {
    final user = _requireCurrentUser();
    final completedAt = DateTime.now();
    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': _profile?.displayName ?? '',
      'role_title': _profile?.roleTitle ?? '',
      'seniority_band': seniorityBandToDb(
        _profile?.seniorityBand ?? SeniorityBand.manager,
      ),
      'industry': _profile?.industry ?? '',
      'timezone': _profile?.timezone ?? DateTime.now().timeZoneName,
      'weekly_goal_count': weeklyGoalCount,
      'communication_contexts': communicationContexts,
      'goals': goals,
      'microphone_consent': microphoneConsent,
      'preferred_response_mode': responseModeToDb(preferredResponseMode),
      'onboarding_completed_at': completedAt.toUtc().toIso8601String(),
      'baseline_completed_at': _profile?.baselineCompletedAt
          ?.toUtc()
          .toIso8601String(),
    }, onConflict: 'id');

    // Cancel any in-flight sync so it doesn't overwrite our fresh local state.
    _syncEpoch++;
    _profile =
        (_profile ??
                UserProfile(
                  userId: user.id,
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
                ))
            .copyWith(
              weeklyGoalCount: weeklyGoalCount,
              communicationContexts: communicationContexts,
              goals: goals,
              microphoneConsent: microphoneConsent,
              preferredResponseMode: preferredResponseMode,
              onboardingCompletedAt: completedAt,
            );
    _publish();
  }

  @override
  Future<TrainingSession> openBaselineSession(int index) async {
    final prompt = baselinePrompts[index];
    final existing = _sessions
        .where(
          (session) =>
              session.origin == SessionOrigin.baseline &&
              session.prompt.id == prompt.id &&
              !session.isCompleted,
        )
        .firstOrNull;
    if (existing != null) {
      return existing;
    }

    final row = await _client
        .from('training_sessions')
        .insert({
          'user_id': _requireCurrentUser().id,
          'prompt_id': prompt.id,
          'origin': sessionOriginToDb(SessionOrigin.baseline),
          'device_mode': responseModeToDb(
            _profile?.preferredResponseMode ?? ResponseMode.typed,
          ),
        })
        .select()
        .single();
    final session = trainingSessionFromRow(
      Map<String, dynamic>.from(row),
      prompt: prompt,
      attempts: const [],
      reviews: const [],
    );
    _sessions.insert(0, session);
    _syncEpoch++;
    _publish();
    return session;
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
    if (planItem == null) {
      throw StateError('Plan item not found.');
    }
    final prompt = _promptLibrary.firstWhere((item) => item.id == planItem.promptId);

    final row = await _client
        .from('training_sessions')
        .insert({
          'user_id': _requireCurrentUser().id,
          'plan_item_id': planItemId,
          'prompt_id': prompt.id,
          'origin': sessionOriginToDb(SessionOrigin.dailyPlan),
          'device_mode': responseModeToDb(
            _profile?.preferredResponseMode ?? ResponseMode.typed,
          ),
        })
        .select()
        .single();
    final session = trainingSessionFromRow(
      Map<String, dynamic>.from(row),
      prompt: prompt,
      attempts: const [],
      reviews: const [],
    );
    _sessions.insert(0, session);
    _syncEpoch++;
    _publish();
    return session;
  }

  @override
  Future<TrainingSession> openRetrySession(String sessionId) async {
    final existing = _sessions
        .where((session) => session.id == sessionId)
        .firstOrNull;
    if (existing != null) {
      return existing;
    }

    final session = await _fetchSessionById(sessionId);
    if (session == null) {
      throw StateError('Session not found.');
    }

    _sessions.removeWhere((item) => item.id == session.id);
    _sessions.insert(0, session);
    _syncEpoch++;
    _publish();
    return session;
  }

  @override
  Future<TrainingSession> submitAttempt({
    required String sessionId,
    required String responseText,
    required ResponseMode responseMode,
  }) async {
    final sessionIndex = _sessions.indexWhere((session) => session.id == sessionId);
    if (sessionIndex == -1) {
      throw StateError('Session not found.');
    }

    final session = _sessions[sessionIndex];
    final nextAttemptNo = session.attempts.length + 1;
    final trimmedText = responseText.trim();
    final wordCount = _wordCount(trimmedText);
    final estimatedDurationSeconds = max(
      session.prompt.targetDurationSec - 5,
      (wordCount / 140 * 60).round(),
    );

    await _client
        .from('training_sessions')
        .update({'device_mode': responseModeToDb(responseMode)})
        .eq('id', sessionId);

    final attemptRow = await _client
        .from('session_attempts')
        .insert({
          'training_session_id': sessionId,
          'attempt_no': nextAttemptNo,
          'duration_ms': estimatedDurationSeconds * 1000,
          'transcript_text': trimmedText,
          'word_count': wordCount,
          'word_timings': const [],
          'response_mode': responseModeToDb(responseMode),
        })
        .select()
        .single();

    final scored = ScoringEngine.evaluate(
      prompt: session.prompt,
      responseText: trimmedText,
      responseMode: responseMode,
      previousAttempt: session.attempts.isEmpty ? null : session.attempts.last,
    );
    final attemptId = attemptRow['id'].toString();

    await _client.from('session_scores').insert(
      sessionScoreToRow(scored.score, attemptId: attemptId),
    );
    await _client.from('session_feedback').insert(
      sessionFeedbackToRow(scored.feedback, attemptId: attemptId),
    );

    final updated = session.copyWith(
      attempts: [
        ...session.attempts,
        sessionAttemptFromRow(Map<String, dynamic>.from(attemptRow)),
      ],
      reviews: [
        ...session.reviews,
        AttemptReview(score: scored.score, feedback: scored.feedback),
      ],
    );
    _sessions[sessionIndex] = updated;
    _syncEpoch++;
    _publish();
    return updated;
  }

  @override
  Future<void> finalizeSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((session) => session.id == sessionId);
    if (sessionIndex == -1) {
      return;
    }

    final session = _sessions[sessionIndex];
    if (session.reviews.isEmpty) {
      return;
    }

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

    final completedAt = DateTime.now();
    final completed = session.copyWith(
      status: SessionStatus.completed,
      completedAt: completedAt,
      bestAttemptNo: bestAttemptIndex + 1,
      finalScore: bestReview.score.overallScore,
      scoreDelta: scoreDelta,
    );
    _sessions[sessionIndex] = completed;
    _syncEpoch++;

    await _client
        .from('training_sessions')
        .update({
          'status': sessionStatusToDb(SessionStatus.completed),
          'completed_at': completedAt.toUtc().toIso8601String(),
          'best_attempt_no': completed.bestAttemptNo,
          'final_score': completed.finalScore,
          'score_delta': completed.scoreDelta,
        })
        .eq('id', sessionId);

    if (completed.planItemId != null) {
      await _client
          .from('plan_items')
          .update({'status': planItemStatusToDb(PlanItemStatus.completed)})
          .eq('id', completed.planItemId!);
      _markPlanItemCompletedInCache(completed.planItemId!);
    }

    if (_baselineSummary == null && _allBaselineSessionsCompleted()) {
      await _completeBaselineAndGeneratePlan();
    } else if (_baselineSummary != null) {
      await _refreshProgressFromCompletedSessions();
    }

    _publish();
  }

  @override
  Future<WeeklyRecalibration> generateWeeklyRecalibration() async {
    final progress = _progress;
    final plan = _currentPlan;
    if (progress == null || plan == null) {
      throw StateError('Progress has not been initialized.');
    }

    final recalibration = AdaptiveEngine.generateWeeklyRecalibration(
      weekNumber: _currentWeekNumber(),
      progress: progress,
      sessions: _sessions,
    );
    final row = await _client
        .from('weekly_recalibrations')
        .insert({
          'user_id': _requireCurrentUser().id,
          'training_plan_id': plan.id,
          'from_version_id': plan.currentVersion.id,
          'to_version_id': plan.currentVersion.id,
          'week_number': recalibration.weekNumber,
          'classification': recalibrationStateToDb(recalibration.classification),
          'signal_snapshot': {
            'overall_score_ema': progress.overallScoreEma,
            'readiness_score': progress.readinessScore,
            'weekly_completion_rate': progress.weeklyCompletionRate,
          },
          'rule_hits': recalibration.ruleHits,
          'changes_summary': recalibration.changesSummary,
        })
        .select()
        .single();

    final saved = weeklyRecalibrationFromRow(Map<String, dynamic>.from(row));
    _recalibrations.insert(0, saved);
    _progress = progress.copyWith(latestRecalibrationState: saved.classification);

    await _client
        .from('user_progress')
        .update({
          'latest_recalibration_state': recalibrationStateToDb(saved.classification),
        })
        .eq('user_id', _requireCurrentUser().id);

    _publish();
    return saved;
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncWithAuthSession() async {
    final epoch = ++_syncEpoch;
    final user = _client.auth.currentUser;

    if (user == null) {
      _resetState();
      _isLoading = false;
      _publish();
      return;
    }

    _currentUser = appUserFromSupabaseUser(user);
    _isLoading = true;
    _publish();

    try {
      final loadedPrompts = await _fetchPromptLibrary();
      final loadedProfile = await _fetchProfile(user.id);
      final loadedBaseline = await _fetchBaseline(user.id);
      final loadedPlan = await _fetchTrainingPlan(user.id, loadedPrompts);
      final loadedSessions = await _fetchSessions(user.id, loadedPrompts);
      final loadedProgress = await _fetchProgress(
        user.id,
        loadedSessions,
        loadedPlan,
      );
      final loadedRecalibrations = await _fetchRecalibrations(user.id);

      if (_disposed || epoch != _syncEpoch) {
        return;
      }

      _promptLibrary
        ..clear()
        ..addAll(loadedPrompts);
      _profile = loadedProfile;
      _baselineSummary = loadedBaseline;
      _currentPlan = loadedPlan;
      _sessions
        ..clear()
        ..addAll(loadedSessions);
      _progress = loadedProgress;
      _recalibrations
        ..clear()
        ..addAll(loadedRecalibrations);
    } catch (error, stackTrace) {
      debugPrint('Supabase sync failed: $error\n$stackTrace');
    } finally {
      if (!_disposed && epoch == _syncEpoch) {
        _isLoading = false;
        _publish();
      }
    }
  }

  Future<List<PromptTemplate>> _fetchPromptLibrary() async {
    final rows = await _client
        .from('prompts')
        .select()
        .eq('is_active', true)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List)
        .map(promptTemplateFromRow)
        .toList();
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return userProfileFromRow(Map<String, dynamic>.from(row));
  }

  Future<CommunicationBaseline?> _fetchBaseline(String userId) async {
    final row = await _client
        .from('communication_baselines')
        .select()
        .eq('user_id', userId)
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return communicationBaselineFromRow(Map<String, dynamic>.from(row));
  }

  Future<TrainingPlan?> _fetchTrainingPlan(
    String userId,
    List<PromptTemplate> prompts,
  ) async {
    final planRow = await _client
        .from('training_plans')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (planRow == null) {
      return null;
    }

    final currentVersionId = planRow['current_version_id'];
    if (currentVersionId == null) {
      return null;
    }

    final versionRow = await _client
        .from('training_plan_versions')
        .select()
        .eq('id', currentVersionId)
        .single();
    final itemRows = await _client
        .from('plan_items')
        .select()
        .eq('plan_version_id', currentVersionId)
        .order('sequence_number');

    final items = List<Map<String, dynamic>>.from(itemRows as List)
        .map(planItemFromRow)
        .toList();
    final currentVersion = trainingPlanVersionFromRow(
      Map<String, dynamic>.from(versionRow),
      items: items,
    );

    return trainingPlanFromRows(
      planRow: Map<String, dynamic>.from(planRow),
      currentVersion: currentVersion,
      previousVersions: const [],
    );
  }

  Future<List<TrainingSession>> _fetchSessions(
    String userId,
    List<PromptTemplate> prompts,
  ) async {
    final sessionRows = await _client
        .from('training_sessions')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false);

    final sessionMaps = List<Map<String, dynamic>>.from(sessionRows as List);
    if (sessionMaps.isEmpty) {
      return [];
    }

    final promptById = {for (final prompt in prompts) prompt.id: prompt};
    final sessionIds = sessionMaps.map((row) => row['id'].toString()).toList();

    final attemptRows = await _client
        .from('session_attempts')
        .select()
        .inFilter('training_session_id', sessionIds)
        .order('submitted_at');
    final attemptMaps = List<Map<String, dynamic>>.from(attemptRows as List);
    final attemptIds = attemptMaps.map((row) => row['id'].toString()).toList();

    final scoreByAttemptId = <String, Map<String, dynamic>>{};
    final feedbackByAttemptId = <String, Map<String, dynamic>>{};

    if (attemptIds.isNotEmpty) {
      final scoreRows = await _client
          .from('session_scores')
          .select()
          .inFilter('session_attempt_id', attemptIds);
      for (final row in List<Map<String, dynamic>>.from(scoreRows as List)) {
        scoreByAttemptId[row['session_attempt_id'].toString()] = row;
      }

      final feedbackRows = await _client
          .from('session_feedback')
          .select()
          .inFilter('session_attempt_id', attemptIds);
      for (final row in List<Map<String, dynamic>>.from(feedbackRows as List)) {
        feedbackByAttemptId[row['session_attempt_id'].toString()] = row;
      }
    }

    final attemptsBySessionId = <String, List<SessionAttempt>>{};
    final reviewsBySessionId = <String, List<AttemptReview>>{};

    for (final row in attemptMaps) {
      final sessionId = row['training_session_id'].toString();
      final attemptId = row['id'].toString();
      attemptsBySessionId.putIfAbsent(sessionId, () => []);
      reviewsBySessionId.putIfAbsent(sessionId, () => []);
      attemptsBySessionId[sessionId]!.add(sessionAttemptFromRow(row));

      final scoreRow = scoreByAttemptId[attemptId];
      final feedbackRow = feedbackByAttemptId[attemptId];
      if (scoreRow != null && feedbackRow != null) {
        reviewsBySessionId[sessionId]!.add(
          AttemptReview(
            score: sessionScoreFromRow(scoreRow),
            feedback: sessionFeedbackFromRow(feedbackRow),
          ),
        );
      }
    }

    final sessions = <TrainingSession>[];
    for (final row in sessionMaps) {
      final prompt = promptById[row['prompt_id'].toString()];
      if (prompt == null) {
        continue;
      }
      final sessionId = row['id'].toString();
      sessions.add(
        trainingSessionFromRow(
          row,
          prompt: prompt,
          attempts: attemptsBySessionId[sessionId] ?? const [],
          reviews: reviewsBySessionId[sessionId] ?? const [],
        ),
      );
    }
    return sessions;
  }

  Future<TrainingSession?> _fetchSessionById(String sessionId) async {
    final row = await _client
        .from('training_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    if (row == null) {
      return null;
    }

    final promptId = row['prompt_id'].toString();
    var prompt = _promptLibrary.where((item) => item.id == promptId).firstOrNull;
    if (prompt == null) {
      final promptRow = await _client
          .from('prompts')
          .select()
          .eq('id', promptId)
          .single();
      prompt = promptTemplateFromRow(Map<String, dynamic>.from(promptRow));
    }

    final attemptRows = await _client
        .from('session_attempts')
        .select()
        .eq('training_session_id', sessionId)
        .order('submitted_at');
    final attemptMaps = List<Map<String, dynamic>>.from(attemptRows as List);
    final attemptIds = attemptMaps.map((item) => item['id'].toString()).toList();

    final scoreByAttemptId = <String, Map<String, dynamic>>{};
    final feedbackByAttemptId = <String, Map<String, dynamic>>{};
    if (attemptIds.isNotEmpty) {
      final scoreRows = await _client
          .from('session_scores')
          .select()
          .inFilter('session_attempt_id', attemptIds);
      for (final item in List<Map<String, dynamic>>.from(scoreRows as List)) {
        scoreByAttemptId[item['session_attempt_id'].toString()] = item;
      }

      final feedbackRows = await _client
          .from('session_feedback')
          .select()
          .inFilter('session_attempt_id', attemptIds);
      for (final item in List<Map<String, dynamic>>.from(feedbackRows as List)) {
        feedbackByAttemptId[item['session_attempt_id'].toString()] = item;
      }
    }

    final attempts = <SessionAttempt>[];
    final reviews = <AttemptReview>[];
    for (final item in attemptMaps) {
      attempts.add(sessionAttemptFromRow(item));
      final attemptId = item['id'].toString();
      final scoreRow = scoreByAttemptId[attemptId];
      final feedbackRow = feedbackByAttemptId[attemptId];
      if (scoreRow != null && feedbackRow != null) {
        reviews.add(
          AttemptReview(
            score: sessionScoreFromRow(scoreRow),
            feedback: sessionFeedbackFromRow(feedbackRow),
          ),
        );
      }
    }

    return trainingSessionFromRow(
      Map<String, dynamic>.from(row),
      prompt: prompt,
      attempts: attempts,
      reviews: reviews,
    );
  }

  Future<ProgressSnapshot?> _fetchProgress(
    String userId,
    List<TrainingSession> sessions,
    TrainingPlan? currentPlan,
  ) async {
    final row = await _client
        .from('user_progress')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return null;
    }

    final historyRows = await _client
        .from('pillar_progress_history')
        .select()
        .eq('user_id', userId)
        .order('recorded_on')
        .order('created_at');
    final pillarHistory = List<Map<String, dynamic>>.from(historyRows as List)
        .map(pillarProgressPointFromRow)
        .toList();

    final pillarScores = <Pillar, double>{
      for (final pillar in Pillar.values) pillar: 0,
    };
    for (final point in pillarHistory) {
      pillarScores[point.pillar] = point.score;
    }

    final completedSessions = sessions
        .where((session) => session.isCompleted && session.finalScore != null)
        .toList()
      ..sort((a, b) {
        final left = a.completedAt ?? a.startedAt;
        final right = b.completedAt ?? b.startedAt;
        return left.compareTo(right);
      });
    var overallTrend = completedSessions
        .map((session) => session.finalScore ?? 0)
        .toList();
    if (overallTrend.length > 8) {
      overallTrend = overallTrend.sublist(overallTrend.length - 8);
    }

    final missedSessions = currentPlan?.currentVersion.items
            .where((item) => item.status == PlanItemStatus.missed)
            .length ??
        0;

    return progressSnapshotFromRow(
      Map<String, dynamic>.from(row),
      pillarScores: pillarScores,
      overallTrend: overallTrend,
      pillarHistory: pillarHistory,
      missedSessions: missedSessions,
    );
  }

  Future<List<WeeklyRecalibration>> _fetchRecalibrations(String userId) async {
    final rows = await _client
        .from('weekly_recalibrations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List)
        .map(weeklyRecalibrationFromRow)
        .toList();
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

  Future<void> _completeBaselineAndGeneratePlan() async {
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

    final baselineCompletedAt = DateTime.now();
    final baselineRow = await _client
        .from('communication_baselines')
        .insert({
          'user_id': _currentUser!.id,
          'completed_at': baselineCompletedAt.toUtc().toIso8601String(),
          'overall_score': overallAverage,
          'assigned_level': communicationLevelToDb(level),
          'readiness_score': readiness,
          'strength_pillars': ranked.reversed
              .take(2)
              .map((entry) => pillarToDb(entry.key))
              .toList(),
          'weak_pillars': ranked.take(2).map((entry) => pillarToDb(entry.key)).toList(),
          'behavior_snapshot': behaviorMetricsToDb(behaviorSnapshot),
          'summary_text':
              'You have a credible foundation, but the biggest upside still comes from faster answers and cleaner structure.',
        })
        .select()
        .single();

    await _client
        .from('profiles')
        .update({
          'baseline_completed_at': baselineCompletedAt.toUtc().toIso8601String(),
        })
        .eq('id', _currentUser!.id);

    _baselineSummary = communicationBaselineFromRow(
      Map<String, dynamic>.from(baselineRow),
    );
    _profile = _profile?.copyWith(baselineCompletedAt: baselineCompletedAt);

    await _persistInitialTrainingPlan();

    final initialHistory = [
      for (final entry in averages.entries)
        PillarProgressPoint(
          pillar: entry.key,
          score: entry.value,
          recordedOn: DateTime.now(),
          weekNumber: 0,
        ),
    ];

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
      overallTrend: completed.map((session) => session.finalScore ?? 0).toList(),
      pillarHistory: initialHistory,
      missedSessions: 0,
      lastSessionAt: DateTime.now(),
    );

    await _persistProgressSnapshot(
      _progress!,
      historyPoints: initialHistory,
    );
  }

  Future<void> _persistInitialTrainingPlan() async {
    final profile = _profile;
    final baseline = _baselineSummary;
    final user = _currentUser;
    if (profile == null || baseline == null || user == null) {
      return;
    }

    final generated = AdaptiveEngine.generateInitialPlan(
      userId: user.id,
      baseline: baseline,
      profile: profile,
      promptLibrary: promptLibrary,
    );

    await _client.from('training_plans').insert({
      'user_id': user.id,
      'start_date': toDbDate(generated.startDate),
      'target_end_date': toDbDate(generated.targetEndDate),
      'status': generated.status,
      'created_from_baseline_id': baseline.id,
    });

    final versionId = (await _client.rpc(
      'publish_training_plan_version',
      params: {
        'p_user_id': user.id,
        'p_source': generated.currentVersion.source,
        'p_payload': {
          'summary': generated.currentVersion.rationaleText,
          'items': [
            for (final item in generated.currentVersion.items)
              {
                'week_number': item.weekNumber,
                'day_number': item.dayNumber,
                'sequence_number': item.sequenceNumber,
                'scheduled_for': toDbDate(item.scheduledFor),
                'drill_type': item.drillType,
                'prompt_id': item.promptId,
                'focus_pillars': item.focusPillars
                    .map(pillarToDb)
                    .toList(),
                'difficulty_tier': item.difficultyTier,
                'target_metrics': item.targetMetrics,
                'status': planItemStatusToDb(item.status),
              },
          ],
        },
      },
    ))
        .toString();

    await _client.from('plan_items').insert([
      for (final item in generated.currentVersion.items)
        {
          'plan_version_id': versionId,
          'user_id': user.id,
          'week_number': item.weekNumber,
          'day_number': item.dayNumber,
          'sequence_number': item.sequenceNumber,
          'scheduled_for': toDbDate(item.scheduledFor),
          'drill_type': item.drillType,
          'prompt_id': item.promptId,
          'focus_pillars': item.focusPillars.map(pillarToDb).toList(),
          'difficulty_tier': item.difficultyTier,
          'target_metrics': item.targetMetrics,
          'status': planItemStatusToDb(item.status),
          'unlock_rule': const <String, dynamic>{},
        },
    ]);

    _currentPlan = await _fetchTrainingPlan(user.id, _promptLibrary);
  }

  Future<void> _refreshProgressFromCompletedSessions() async {
    final progress = _progress;
    if (progress == null) {
      return;
    }

    final completed = _sessions
        .where((session) => session.isCompleted)
        .toList()
      ..sort((a, b) {
        final left = a.completedAt ?? a.startedAt;
        final right = b.completedAt ?? b.startedAt;
        return left.compareTo(right);
      });
    final finalSessions = completed
        .map((session) => session.reviews[(session.bestAttemptNo ?? 1) - 1])
        .toList();
    if (finalSessions.isEmpty) {
      return;
    }

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

    var trend = [...progress.overallTrend, overall];
    if (trend.length > 8) {
      trend = trend.sublist(trend.length - 8);
    }
    final historyPoints = [
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
      overallTrend: trend,
      pillarHistory: [...progress.pillarHistory, ...historyPoints],
      lastSessionAt: DateTime.now(),
    );

    await _persistProgressSnapshot(_progress!, historyPoints: historyPoints);
  }

  Future<void> _persistProgressSnapshot(
    ProgressSnapshot snapshot, {
    required List<PillarProgressPoint> historyPoints,
  }) async {
    final userId = _requireCurrentUser().id;
    await _client.from('user_progress').upsert({
      'user_id': userId,
      'current_level': communicationLevelToDb(snapshot.currentLevel),
      'overall_score_ema': snapshot.overallScoreEma,
      'readiness_score': snapshot.readinessScore,
      'current_streak': snapshot.currentStreak,
      'total_xp': snapshot.totalXp,
      'weekly_completion_rate': snapshot.weeklyCompletionRate,
      'coaching_adoption_rate': snapshot.coachingAdoptionRate,
      'difficulty_tolerance': snapshot.difficultyTolerance,
      'latest_recalibration_state': recalibrationStateToDb(
        snapshot.latestRecalibrationState,
      ),
      'last_session_at': snapshot.lastSessionAt?.toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    if (historyPoints.isNotEmpty) {
      await _client.from('pillar_progress_history').insert([
        for (final point in historyPoints)
          {
            'user_id': userId,
            'pillar': pillarToDb(point.pillar),
            'score': point.score,
            'source_type': 'app_sync',
            'source_id': null,
            'recorded_on': toDbDate(point.recordedOn),
            'week_number': point.weekNumber,
          },
      ]);
    }
  }

  void _markPlanItemCompletedInCache(String planItemId) {
    final plan = _currentPlan;
    if (plan == null) {
      return;
    }

    final updatedItems = plan.currentVersion.items.map((item) {
      if (item.id == planItemId) {
        return item.copyWith(status: PlanItemStatus.completed);
      }
      return item;
    }).toList();

    _currentPlan = plan.copyWith(
      currentVersion: TrainingPlanVersion(
        id: plan.currentVersion.id,
        versionNumber: plan.currentVersion.versionNumber,
        source: plan.currentVersion.source,
        generatedAt: plan.currentVersion.generatedAt,
        rationaleText: plan.currentVersion.rationaleText,
        items: updatedItems,
      ),
    );
  }

  double _coachingAdoptionRate() {
    final completed = _sessions.where(
      (session) => session.isCompleted && session.reviews.length > 1,
    );
    if (completed.isEmpty) {
      return 0.5;
    }
    final improved = completed
        .where((session) => (session.scoreDelta ?? 0) >= 3)
        .length;
    return improved / completed.length;
  }

  double _weeklyCompletionRate() {
    final plan = _currentPlan;
    if (plan == null) {
      return 1;
    }

    final thisWeek = plan.currentVersion.items
        .where((item) => item.weekNumber == _currentWeekNumber())
        .toList();
    if (thisWeek.isEmpty) {
      return 1;
    }
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
    if (completed.isEmpty) {
      return 0.55;
    }
    final highestTier = completed
        .map((session) => session.prompt.difficultyTier)
        .fold<int>(1, max);
    final atHighest = completed
        .where((session) => session.prompt.difficultyTier == highestTier)
        .toList();
    if (atHighest.isEmpty) {
      return 0.55;
    }
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

    if (completed.isEmpty) {
      return 0;
    }

    var streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final found = completed.any(
        (session) => _isSameDay(session.completedAt!, cursor),
      );
      if (!found) {
        break;
      }
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
    if (plan == null) {
      return 1;
    }
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

  AppUser _requireCurrentUser() {
    final user = _currentUser;
    if (user == null) {
      throw StateError('A signed-in user is required.');
    }
    return user;
  }

  void _resetState() {
    _currentUser = null;
    _profile = null;
    _baselineSummary = null;
    _currentPlan = null;
    _progress = null;
    _promptLibrary.clear();
    _sessions.clear();
    _recalibrations.clear();
  }

  void _publish() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
