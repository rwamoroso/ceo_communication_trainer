import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ceo_communication_trainer/app/bootstrap/app_config.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/features/training_plan/domain/adaptive_engine.dart';
import 'package:ceo_communication_trainer/features/training_plan/domain/weekly_lesson_packet_engine.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/drill_guidance.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/session_evaluation_engine.dart';
import 'package:ceo_communication_trainer/services/app_service.dart';
import 'package:ceo_communication_trainer/services/demo/prompt_seed.dart';
import 'package:ceo_communication_trainer/services/supabase/supabase_mappers.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAppService extends AppService {
  static const _manualAiScoringVersion = 'manual-ai-v1';
  static const _manualAiFeedbackVersion = 'manual-ai-v1';

  SupabaseAppService({
    required SupabaseClient client,
    required AppConfig config,
  }) : _client = client,
       _config = config {
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _isInPasswordRecovery = true;
        _publish();
      } else {
        if (_isInPasswordRecovery &&
            state.event == AuthChangeEvent.userUpdated) {
          _isInPasswordRecovery = false;
        }
        unawaited(_syncWithAuthSession());
      }
    });
    unawaited(_syncWithAuthSession());
  }

  final SupabaseClient _client;
  final AppConfig _config;

  StreamSubscription<AuthState>? _authSubscription;
  final List<TrainingSession> _sessions = [];
  final List<WeeklyRecalibration> _recalibrations = [];
  final List<WeeklyLessonPacket> _weeklyLessonPackets = [];
  final List<PromptTemplate> _promptLibrary = [];

  AppUser? _currentUser;
  UserProfile? _profile;
  CommunicationBaseline? _baselineSummary;
  TrainingPlan? _currentPlan;
  ProgressSnapshot? _progress;
  bool _isLoading = true;
  bool _isInPasswordRecovery = false;
  bool _disposed = false;
  int _syncEpoch = 0;

  static final List<String> _baselinePromptOrder = seededPrompts
      .where((prompt) => prompt.slug.startsWith('baseline-'))
      .map((prompt) => prompt.slug)
      .toList();

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isInPasswordRecovery => _isInPasswordRecovery;

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
    final prompts =
        _promptLibrary
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
  List<WeeklyLessonPacket> get weeklyLessonPackets =>
      List.unmodifiable(_weeklyLessonPackets.reversed);

  @override
  WeeklyLessonPacket? weeklyLessonPacketForWeek(int weekNumber) {
    final currentVersionId = _currentPlan?.currentVersion.id;
    if (currentVersionId == null) {
      return null;
    }
    return _weeklyLessonPackets
        .where(
          (packet) =>
              packet.planVersionId == currentVersionId &&
              packet.weekNumber == weekNumber,
        )
        .firstOrNull;
  }

  @override
  WeeklyDrillLesson? weeklyLessonForPlanItem(String planItemId) {
    final item = _currentPlan?.currentVersion.items
        .where((entry) => entry.id == planItemId)
        .firstOrNull;
    if (item == null) {
      return null;
    }
    return weeklyLessonPacketForWeek(
      item.weekNumber,
    )?.lessonForPlanItem(planItemId);
  }

  @override
  DashboardSnapshot? get dashboard {
    final progress = _progress;
    if (progress == null) {
      return null;
    }
    final plan = _currentPlan;
    if (plan == null) {
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
        todayItems: const [],
        upcomingItems: const [],
        weakestPillar: weakestPillar,
        latestImprovement: latestImprovement,
        progress: progress,
      );
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
  Future<void> signIn(
    String email,
    String password, {
    bool isSignUp = false,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (isSignUp) {
      await _client.auth.signUp(email: normalizedEmail, password: password);
    } else {
      await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: _passwordResetRedirectTo,
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
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
      'daily_reminder_time': _profile?.dailyReminderTime ?? '',
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
                  dailyReminderTime: '',
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
      'daily_reminder_time': _profile?.dailyReminderTime ?? '',
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
                  dailyReminderTime: '',
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
  Future<void> updateDailyReminderTime(String? dailyReminderTime) async {
    final user = _requireCurrentUser();
    final normalized = (dailyReminderTime ?? '').trim();
    await _client
        .from('profiles')
        .update({'daily_reminder_time': normalized})
        .eq('id', user.id);

    _syncEpoch++;
    _profile = _profile?.copyWith(dailyReminderTime: normalized);
    _publish();
  }

  @override
  Future<TrainingSession> openBaselineSession(int index) async {
    final prompt = baselinePrompts[index];
    debugPrint(
      'openBaselineSession index=$index prompt=${prompt.id} '
      'cachedSessions=${_sessions.length}',
    );
    final existing = _sessions
        .where(
          (session) =>
              session.origin == SessionOrigin.baseline &&
              session.prompt.id == prompt.id &&
              !session.isCompleted,
        )
        .firstOrNull;
    if (existing != null) {
      debugPrint(
        'openBaselineSession.reuse session=${existing.id} '
        'attempts=${existing.attempts.length} reviews=${existing.reviews.length}',
      );
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
    debugPrint(
      'openBaselineSession.created session=${session.id} prompt=${prompt.id}',
    );
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
    if (weeklyLessonPacketForWeek(planItem.weekNumber) == null) {
      throw StateError(
        'Week ${planItem.weekNumber} requires an imported AI lesson packet before drills can start.',
      );
    }
    final prompt = _promptLibrary.firstWhere(
      (item) => item.id == planItem.promptId,
    );

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
    debugPrint('openRetrySession session=$sessionId');
    final existing = _sessions
        .where((session) => session.id == sessionId)
        .firstOrNull;
    if (existing != null && existing.reviews.isNotEmpty) {
      debugPrint(
        'openRetrySession.reuse session=${existing.id} '
        'attempts=${existing.attempts.length} reviews=${existing.reviews.length}',
      );
      _publish();
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
    debugPrint(
      'openRetrySession.fetched session=${session.id} '
      'attempts=${session.attempts.length} reviews=${session.reviews.length}',
    );
    return session;
  }

  @override
  Future<TrainingSession> submitAttempt({
    required String sessionId,
    required String responseText,
    required ResponseMode responseMode,
  }) async {
    debugPrint(
      'submitAttempt.start session=$sessionId responseMode=$responseMode',
    );
    final sessionIndex = _sessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (sessionIndex == -1) {
      throw StateError('Session not found.');
    }

    final session = _sessions[sessionIndex];
    if (session.attempts.length >= 2) {
      throw StateError(
        'This session already has two attempts. Open feedback and finish the session.',
      );
    }
    if (session.attempts.length > session.reviews.length) {
      throw StateError(
        'Import AI coaching for the latest attempt before submitting another response.',
      );
    }
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

    Map<String, dynamic> attemptRow;
    try {
      attemptRow = Map<String, dynamic>.from(
        await _client
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
            .single(),
      );
      debugPrint(
        'submitAttempt.attemptInserted session=$sessionId '
        'attempt=${attemptRow['id']}',
      );
    } on PostgrestException catch (e) {
      if (e.code == '23514') {
        final fresh = await _fetchSessionById(sessionId);
        if (fresh != null) {
          final freshIndex = _sessions.indexWhere((s) => s.id == sessionId);
          if (freshIndex != -1) {
            _sessions[freshIndex] = fresh;
          } else {
            _sessions.insert(0, fresh);
          }
          _syncEpoch++;
          _publish();
        }
        throw StateError(
          'This session already reached the 2-attempt limit. Open feedback and finish the session.',
        );
      }
      rethrow;
    }

    // Re-look up after all DB awaits — a background sync may have reloaded
    // _sessions with a fresh version of this session.
    final freshIndex = _sessions.indexWhere((s) => s.id == sessionId);
    final freshSession = freshIndex != -1 ? _sessions[freshIndex] : session;
    final newAttempt = sessionAttemptFromRow(
      Map<String, dynamic>.from(attemptRow),
    );
    final updated = freshSession.copyWith(
      attempts: freshSession.attempts.any((a) => a.id == newAttempt.id)
          ? freshSession.attempts
          : [...freshSession.attempts, newAttempt],
    );
    if (freshIndex != -1) {
      _sessions[freshIndex] = updated;
    } else {
      _sessions.insert(0, updated);
    }
    _syncEpoch++;
    _publish();
    debugPrint(
      'submitAttempt.complete session=$sessionId '
      'attempts=${updated.attempts.length} reviews=${updated.reviews.length}',
    );
    return updated;
  }

  @override
  Future<String> buildSessionEvaluationPrompt(String sessionId) async {
    final session = _sessions.firstWhere(
      (entry) => entry.id == sessionId,
      orElse: () => throw StateError('Session not found.'),
    );
    if (session.attempts.isEmpty) {
      throw StateError('Submit a response before requesting coaching.');
    }
    if (session.reviews.length >= session.attempts.length) {
      throw StateError(
        'The latest attempt already has coaching. Retry the session to generate a new prompt.',
      );
    }

    return SessionEvaluationEngine.buildPrompt(
      input: _buildAttemptEvaluationPayload(
        session: session,
        pendingAttempt: session.attempts.last,
      ),
    );
  }

  @override
  Future<TrainingSession> importSessionEvaluation({
    required String sessionId,
    required String rawJson,
  }) async {
    final sessionIndex = _sessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (sessionIndex == -1) {
      throw StateError('Session not found.');
    }

    final session = _sessions[sessionIndex];
    if (session.attempts.isEmpty) {
      throw StateError('Submit a response before importing coaching.');
    }
    if (session.reviews.length >= session.attempts.length) {
      throw StateError('This attempt already has imported coaching.');
    }

    final pendingAttempt = session.attempts.last;
    final parsed = SessionEvaluationEngine.parseImport(
      rawJson: rawJson,
      scoringVersion: _manualAiScoringVersion,
      feedbackVersion: _manualAiFeedbackVersion,
    );

    await _client
        .from('session_scores')
        .insert(
          sessionScoreToRow(
            parsed.scoredAttempt.score,
            attemptId: pendingAttempt.id,
          ),
        );
    await _client
        .from('session_feedback')
        .insert(
          sessionFeedbackToRow(
            parsed.scoredAttempt.feedback,
            attemptId: pendingAttempt.id,
          ),
        );
    await _applyNextDayDrillUpdate(parsed.nextDayDrillUpdate);

    final refreshedIndex = _sessions.indexWhere(
      (entry) => entry.id == sessionId,
    );
    final refreshed = refreshedIndex == -1
        ? session
        : _sessions[refreshedIndex];
    final updated = refreshed.copyWith(
      reviews: [
        ...refreshed.reviews,
        AttemptReview(
          score: parsed.scoredAttempt.score,
          feedback: parsed.scoredAttempt.feedback,
        ),
      ],
    );
    if (refreshedIndex != -1) {
      _sessions[refreshedIndex] = updated;
    } else {
      _sessions.insert(0, updated);
    }
    _syncEpoch++;
    _publish();
    return updated;
  }

  @override
  Future<void> finalizeSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (sessionIndex == -1) {
      return;
    }

    final session = _sessions[sessionIndex];
    if (session.reviews.isEmpty ||
        session.attempts.length > session.reviews.length) {
      throw StateError(
        'Import AI coaching for the latest attempt before finishing this session.',
      );
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
          'classification': recalibrationStateToDb(
            recalibration.classification,
          ),
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
    _progress = progress.copyWith(
      latestRecalibrationState: saved.classification,
    );

    await _client
        .from('user_progress')
        .update({
          'latest_recalibration_state': recalibrationStateToDb(
            saved.classification,
          ),
        })
        .eq('user_id', _requireCurrentUser().id);

    _publish();
    return saved;
  }

  @override
  Future<String> buildWeeklyLessonPrompt(int weekNumber) async {
    final plan = _currentPlan;
    final baseline = _baselineSummary;
    if (plan == null || baseline == null) {
      throw StateError('A completed baseline and active plan are required.');
    }

    final payload = WeeklyLessonPacketEngine.buildPromptInput(
      weekNumber: weekNumber,
      plan: plan,
      baseline: baseline,
      progress: _progress,
      sessions: _sessions,
      previousWeekPacket: weeklyLessonPacketForWeek(weekNumber - 1),
    );
    final accessToken = _client.auth.currentSession?.accessToken;

    try {
      final response = await _client.functions.invoke(
        'build-weekly-lesson-prompt',
        body: payload,
        headers: accessToken == null
            ? null
            : {'Authorization': 'Bearer $accessToken'},
      );
      final data = asMap(response.data);
      final prompt = data['prompt']?.toString().trim() ?? '';
      if (prompt.isNotEmpty) {
        return prompt;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'buildWeeklyLessonPrompt: edge function failed, using local fallback. '
        '$error\n$stackTrace',
      );
    }

    return WeeklyLessonPacketEngine.buildPrompt(
      weekNumber: weekNumber,
      plan: plan,
      baseline: baseline,
      progress: _progress,
      sessions: _sessions,
      previousWeekPacket: weeklyLessonPacketForWeek(weekNumber - 1),
    );
  }

  @override
  Future<WeeklyLessonPacket> generateWeeklyLessonPacket(int weekNumber) async {
    final user = _requireCurrentUser();
    final plan = _currentPlan;
    final baseline = _baselineSummary;
    if (plan == null || baseline == null) {
      throw StateError('A completed baseline and active plan are required.');
    }

    final payload = WeeklyLessonPacketEngine.buildPromptInput(
      weekNumber: weekNumber,
      plan: plan,
      baseline: baseline,
      progress: _progress,
      sessions: _sessions,
      previousWeekPacket: weeklyLessonPacketForWeek(weekNumber - 1),
    );
    final accessToken = _client.auth.currentSession?.accessToken;

    final response = await _client.functions.invoke(
      'build-weekly-lesson-prompt',
      body: payload,
      headers: accessToken == null
          ? null
          : {'Authorization': 'Bearer $accessToken'},
    );
    final data = asMap(response.data);
    final packetPayload = asMap(data['packet']);
    if (packetPayload.isEmpty) {
      throw StateError(
        'Automatic lesson generation is unavailable right now. Use the manual AI prompt instead.',
      );
    }

    final rawJson = const JsonEncoder.withIndent('  ').convert(packetPayload);
    return _persistWeeklyLessonPacket(
      userId: user.id,
      planVersionId: plan.currentVersion.id,
      weekNumber: weekNumber,
      rawJson: rawJson,
    );
  }

  @override
  Future<WeeklyLessonPacket> importWeeklyLessonPacket({
    required int weekNumber,
    required String rawJson,
  }) async {
    final user = _requireCurrentUser();
    final plan = _currentPlan;
    if (plan == null) {
      throw StateError('An active plan is required.');
    }

    return _persistWeeklyLessonPacket(
      userId: user.id,
      planVersionId: plan.currentVersion.id,
      weekNumber: weekNumber,
      rawJson: rawJson,
    );
  }

  Map<String, dynamic> _buildAttemptEvaluationPayload({
    required TrainingSession session,
    required SessionAttempt pendingAttempt,
  }) {
    final profile = _profile;
    final lesson = session.planItemId == null
        ? null
        : weeklyLessonForPlanItem(session.planItemId!);
    final planItem = session.planItemId == null
        ? null
        : _currentPlan?.currentVersion.items
              .where((item) => item.id == session.planItemId)
              .firstOrNull;
    final weeklyPacket = planItem == null
        ? null
        : weeklyLessonPacketForWeek(planItem.weekNumber);
    final previousAttempt = session.attempts.length > 1
        ? session.attempts[session.attempts.length - 2]
        : null;
    final previousReview = session.reviews.isEmpty
        ? null
        : session.reviews.last;
    final nextPlanItem = _nextPlanItemForSession(session);
    final nextLesson = nextPlanItem == null
        ? null
        : weeklyLessonForPlanItem(nextPlanItem.id);

    return {
      'schema_version': 'manual-ai-eval-v1',
      'session': {
        'session_id': session.id,
        'plan_item_id': session.planItemId,
        'origin': sessionOriginToDb(session.origin),
        'attempt_number': pendingAttempt.attemptNo,
        'response_mode': responseModeToDb(pendingAttempt.responseMode),
      },
      'user_profile': profile == null
          ? null
          : {
              'display_name': profile.displayName,
              'role_title': profile.roleTitle,
              'seniority_band': seniorityBandToDb(profile.seniorityBand),
              'industry': profile.industry,
              'timezone': profile.timezone,
              'communication_contexts': profile.communicationContexts,
              'goals': profile.goals,
            },
      'prompt': {
        'id': session.prompt.id,
        'slug': session.prompt.slug,
        'title': session.prompt.title,
        'category': promptCategoryToDb(session.prompt.category),
        'scenario_context': session.prompt.scenarioContext,
        'prompt_text': lesson?.aiPromptText ?? session.prompt.promptText,
        'difficulty_tier': session.prompt.difficultyTier,
        'target_duration_sec': session.prompt.targetDurationSec,
        'target_word_range_min': session.prompt.targetWordRangeMin,
        'target_word_range_max': session.prompt.targetWordRangeMax,
        'pillar_weights': pillarWeightMapToDb(session.prompt.pillarWeights),
        'behavior_targets': session.prompt.behaviorTargets,
      },
      'weekly_lesson': weeklyPacket == null
          ? null
          : {
              'weekly_objective': weeklyPacket.weeklyObjective,
              'development_summary': weeklyPacket.developmentSummary,
              'lesson_title': lesson?.lessonTitle ?? '',
              'lesson_body': lesson?.lessonBody ?? '',
              'good_example': lesson?.goodExample ?? '',
              'example_analysis': lesson?.exampleAnalysis ?? '',
              'user_development_focus': lesson?.userDevelopmentFocus ?? '',
              'pre_drill_checklist':
                  lesson?.preDrillChecklist ?? const <String>[],
              'drill_purpose': DrillGuidance.purposeFor(
                prompt: session.prompt,
                lesson: lesson,
              ),
              'success_signals': DrillGuidance.successSignalsFor(
                prompt: session.prompt,
                lesson: lesson,
              ),
              'ai_scenario_context':
                  lesson?.aiScenarioContext ?? session.prompt.scenarioContext,
              'ai_prompt_text':
                  lesson?.aiPromptText ?? session.prompt.promptText,
            },
      'user_response': {
        'response_text': pendingAttempt.responseText,
        'word_count': pendingAttempt.wordCount,
        'estimated_duration_seconds': pendingAttempt.durationSeconds,
      },
      'previous_attempt': previousAttempt == null || previousReview == null
          ? null
          : {
              'response_text': previousAttempt.responseText,
              'overall_score': previousReview.score.overallScore,
              'biggest_issue': previousReview.feedback.biggestIssue,
              'top_coaching_points': previousReview.feedback.topCoachingPoints,
              'next_attempt_target': previousReview.feedback.nextAttemptTarget,
            },
      'next_scheduled_drill': nextPlanItem == null
          ? null
          : {
              'plan_item_id': nextPlanItem.id,
              'scheduled_for': nextPlanItem.scheduledFor.toIso8601String(),
              'drill_type': nextPlanItem.drillType,
              'user_development_focus': nextLesson?.userDevelopmentFocus ?? '',
              'drill_purpose': nextLesson?.drillPurpose ?? '',
              'success_signals': nextLesson?.successSignals ?? const <String>[],
              'pre_drill_checklist':
                  nextLesson?.preDrillChecklist ?? const <String>[],
              'ai_scenario_context': nextLesson?.aiScenarioContext ?? '',
              'ai_prompt_text': nextLesson?.aiPromptText ?? '',
            },
      'recent_same_topic_history': _recentSameTopicHistory(session),
      'progress': _progress == null
          ? null
          : {
              'current_level': communicationLevelToDb(_progress!.currentLevel),
              'overall_score_ema': _progress!.overallScoreEma,
              'readiness_score': _progress!.readinessScore,
              'weekly_completion_rate': _progress!.weeklyCompletionRate,
              'coaching_adoption_rate': _progress!.coachingAdoptionRate,
              'difficulty_tolerance': _progress!.difficultyTolerance,
              'missed_sessions': _progress!.missedSessions,
            },
    };
  }

  PlanItem? _nextPlanItemForSession(TrainingSession session) {
    if (session.planItemId == null || _currentPlan == null) {
      return null;
    }

    final sorted = [..._currentPlan!.currentVersion.items]
      ..sort((a, b) {
        final weekCompare = a.weekNumber.compareTo(b.weekNumber);
        if (weekCompare != 0) {
          return weekCompare;
        }
        final dayCompare = a.dayNumber.compareTo(b.dayNumber);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return a.sequenceNumber.compareTo(b.sequenceNumber);
      });
    final currentIndex = sorted.indexWhere(
      (item) => item.id == session.planItemId,
    );
    if (currentIndex == -1) {
      return null;
    }

    for (var index = currentIndex + 1; index < sorted.length; index++) {
      final candidate = sorted[index];
      if (candidate.status == PlanItemStatus.scheduled) {
        return candidate;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _recentSameTopicHistory(TrainingSession session) {
    final sameTopic =
        _sessions
            .where(
              (candidate) =>
                  candidate.id != session.id &&
                  candidate.reviews.isNotEmpty &&
                  candidate.prompt.category == session.prompt.category,
            )
            .toList()
          ..sort((a, b) {
            final left = a.completedAt ?? a.startedAt;
            final right = b.completedAt ?? b.startedAt;
            return right.compareTo(left);
          });

    return [
      for (final candidate in sameTopic.take(4))
        {
          'session_id': candidate.id,
          'prompt_title': candidate.prompt.title,
          'response_text': candidate.attempts.isEmpty
              ? ''
              : candidate.attempts.last.responseText,
          'overall_score': candidate.reviews.last.score.overallScore,
          'biggest_issue': candidate.reviews.last.feedback.biggestIssue,
          'next_attempt_target':
              candidate.reviews.last.feedback.nextAttemptTarget,
        },
    ];
  }

  Future<void> _applyNextDayDrillUpdate(NextDayDrillUpdate? update) async {
    if (update == null) {
      return;
    }

    for (var index = 0; index < _weeklyLessonPackets.length; index++) {
      final packet = _weeklyLessonPackets[index];
      final lessonIndex = packet.drills.indexWhere(
        (lesson) => lesson.planItemId == update.planItemId,
      );
      if (lessonIndex == -1) {
        continue;
      }

      final lesson = packet.drills[lessonIndex];
      final updatedLesson = lesson.copyWith(
        userDevelopmentFocus:
            _nonEmptyOrNull(update.userDevelopmentFocus) ??
            lesson.userDevelopmentFocus,
        drillPurpose:
            _nonEmptyOrNull(update.drillPurpose) ?? lesson.drillPurpose,
        successSignals: update.successSignals ?? lesson.successSignals,
        preDrillChecklist: update.preDrillChecklist ?? lesson.preDrillChecklist,
        aiScenarioContext:
            _nonEmptyOrNull(update.aiScenarioContext) ??
            lesson.aiScenarioContext,
        aiPromptText:
            _nonEmptyOrNull(update.aiPromptText) ?? lesson.aiPromptText,
      );
      final updatedDrills = [...packet.drills];
      updatedDrills[lessonIndex] = updatedLesson;
      final updatedPacket = packet.copyWith(
        drills: updatedDrills,
        rawImportText: _packetRawJson(packet.copyWith(drills: updatedDrills)),
        updatedAt: DateTime.now(),
      );

      await _client
          .from('weekly_lesson_packets')
          .update({
            'packet_payload': _packetPayload(updatedPacket),
            'raw_import_text': updatedPacket.rawImportText,
          })
          .eq('id', packet.id);

      _weeklyLessonPackets[index] = updatedPacket;
      return;
    }
  }

  Map<String, dynamic> _packetPayload(WeeklyLessonPacket packet) {
    return {
      'week_number': packet.weekNumber,
      'weekly_objective': packet.weeklyObjective,
      'development_summary': packet.developmentSummary,
      'previous_week_analysis': packet.previousWeekAnalysis,
      'previous_week_evaluations': [
        for (final evaluation in packet.previousWeekEvaluations)
          {
            'session_id': evaluation.sessionId,
            'ai_score': evaluation.aiScore,
            'key_observations': evaluation.keyObservations,
          },
      ],
      'drills': [
        for (final lesson in packet.drills)
          {
            'plan_item_id': lesson.planItemId,
            'lesson_title': lesson.lessonTitle,
            'lesson_body': lesson.lessonBody,
            'good_example': lesson.goodExample,
            'example_analysis': lesson.exampleAnalysis,
            'user_development_focus': lesson.userDevelopmentFocus,
            'pre_drill_checklist': lesson.preDrillChecklist,
            'drill_purpose': lesson.drillPurpose,
            'success_signals': lesson.successSignals,
            if (lesson.aiScenarioContext != null)
              'ai_scenario_context': lesson.aiScenarioContext,
            if (lesson.aiPromptText != null)
              'ai_prompt_text': lesson.aiPromptText,
          },
      ],
    };
  }

  String _packetRawJson(WeeklyLessonPacket packet) {
    return const JsonEncoder.withIndent('  ').convert(_packetPayload(packet));
  }

  String? _nonEmptyOrNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<WeeklyLessonPacket> _persistWeeklyLessonPacket({
    required String userId,
    required String planVersionId,
    required int weekNumber,
    required String rawJson,
  }) async {
    final plan = _currentPlan;
    if (plan == null) {
      throw StateError('An active plan is required.');
    }

    final weekItems = plan.currentVersion.items
        .where((item) => item.weekNumber == weekNumber)
        .toList();
    final validated = WeeklyLessonPacketEngine.parseImport(
      expectedWeekNumber: weekNumber,
      weekItems: weekItems,
      rawJson: rawJson,
    );

    final row = await _client
        .from('weekly_lesson_packets')
        .upsert({
          'plan_version_id': planVersionId,
          'user_id': userId,
          'week_number': validated.weekNumber,
          'weekly_objective': validated.weeklyObjective,
          'development_summary': validated.developmentSummary,
          'packet_payload': validated.toPayload(),
          'raw_import_text': validated.rawImportText,
        }, onConflict: 'plan_version_id,week_number')
        .select()
        .single();

    final packet = weeklyLessonPacketFromRow(Map<String, dynamic>.from(row));
    _weeklyLessonPackets.removeWhere(
      (entry) =>
          entry.planVersionId == packet.planVersionId &&
          entry.weekNumber == packet.weekNumber,
    );
    _weeklyLessonPackets.add(packet);
    _publish();
    return packet;
  }

  @override
  Future<void> reload() => _syncWithAuthSession();

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

    final isInitialLoad = _currentUser == null;
    _currentUser = appUserFromSupabaseUser(user);
    // Only block the UI during initial sign-in. Background token-refresh
    // syncs should update data silently so mutations in flight (submitAttempt,
    // finalizeSession, etc.) don't leave _isLoading stuck at true.
    if (isInitialLoad) {
      _isLoading = true;
      _publish();
    }

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

      var resolvedPlan = loadedPlan;
      var resolvedProgress = loadedProgress;
      var resolvedPackets = <WeeklyLessonPacket>[];

      if (loadedBaseline != null && loadedProfile != null) {
        if (resolvedPlan == null) {
          debugPrint(
            'Supabase sync: missing training plan after baseline; '
            'attempting recovery.',
          );
          try {
            resolvedPlan = await _createInitialTrainingPlan(
              user: _currentUser!,
              profile: loadedProfile,
              baseline: loadedBaseline,
              promptLibrary: loadedPrompts,
            );
          } catch (error, stackTrace) {
            debugPrint('Supabase plan recovery failed: $error\n$stackTrace');
          }
        }

        if (resolvedProgress == null) {
          debugPrint(
            'Supabase sync: missing progress after baseline; '
            'attempting recovery.',
          );
          final recoveredProgress = _buildRecoveredProgressSnapshot(
            baseline: loadedBaseline,
            sessions: loadedSessions,
            currentPlan: resolvedPlan,
          );
          if (recoveredProgress != null) {
            resolvedProgress = recoveredProgress;
            try {
              await _persistProgressSnapshot(
                recoveredProgress,
                historyPoints: recoveredProgress.pillarHistory,
              );
            } catch (error, stackTrace) {
              debugPrint(
                'Supabase progress recovery persistence failed: '
                '$error\n$stackTrace',
              );
            }
          }
        }
      }

      if (resolvedPlan != null) {
        try {
          resolvedPackets = await _fetchWeeklyLessonPackets(
            user.id,
            resolvedPlan.currentVersion.id,
          );
        } catch (error, stackTrace) {
          debugPrint(
            'Supabase weekly lesson packet sync failed: $error\n$stackTrace',
          );
        }
      }

      if (_disposed || epoch != _syncEpoch) {
        return;
      }

      _promptLibrary
        ..clear()
        ..addAll(loadedPrompts);
      _profile = loadedProfile;
      _baselineSummary = loadedBaseline;
      _currentPlan = resolvedPlan;
      _sessions
        ..clear()
        ..addAll(loadedSessions);
      _progress = resolvedProgress;
      _recalibrations
        ..clear()
        ..addAll(loadedRecalibrations);
      _weeklyLessonPackets
        ..clear()
        ..addAll(resolvedPackets);
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
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(promptTemplateFromRow).toList();
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

    final items = List<Map<String, dynamic>>.from(
      itemRows as List,
    ).map(planItemFromRow).toList();
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

  Future<List<WeeklyLessonPacket>> _fetchWeeklyLessonPackets(
    String userId,
    String planVersionId,
  ) async {
    final rows = await _client
        .from('weekly_lesson_packets')
        .select()
        .eq('user_id', userId)
        .eq('plan_version_id', planVersionId)
        .order('week_number');
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(weeklyLessonPacketFromRow).toList();
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
    debugPrint('_fetchSessionById.start session=$sessionId');
    final row = await _client
        .from('training_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    if (row == null) {
      return null;
    }

    final promptId = row['prompt_id'].toString();
    var prompt = _promptLibrary
        .where((item) => item.id == promptId)
        .firstOrNull;
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
    final attemptIds = attemptMaps
        .map((item) => item['id'].toString())
        .toList();

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
      for (final item in List<Map<String, dynamic>>.from(
        feedbackRows as List,
      )) {
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

    final session = trainingSessionFromRow(
      Map<String, dynamic>.from(row),
      prompt: prompt,
      attempts: attempts,
      reviews: reviews,
    );
    debugPrint(
      '_fetchSessionById.complete session=$sessionId '
      'attempts=${session.attempts.length} reviews=${session.reviews.length}',
    );
    return session;
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
    final pillarHistory = List<Map<String, dynamic>>.from(
      historyRows as List,
    ).map(pillarProgressPointFromRow).toList();

    final pillarScores = <Pillar, double>{
      for (final pillar in Pillar.values) pillar: 0,
    };
    for (final point in pillarHistory) {
      pillarScores[point.pillar] = point.score;
    }

    final completedSessions =
        sessions
            .where(
              (session) => session.isCompleted && session.finalScore != null,
            )
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

    final missedSessions =
        currentPlan?.currentVersion.items
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
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(weeklyRecalibrationFromRow).toList();
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
          'weak_pillars': ranked
              .take(2)
              .map((entry) => pillarToDb(entry.key))
              .toList(),
          'behavior_snapshot': behaviorMetricsToDb(behaviorSnapshot),
          'summary_text':
              'You have a credible foundation, but the biggest upside still comes from faster answers and cleaner structure.',
        })
        .select()
        .single();

    await _client
        .from('profiles')
        .update({
          'baseline_completed_at': baselineCompletedAt
              .toUtc()
              .toIso8601String(),
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
      overallTrend: completed
          .map((session) => session.finalScore ?? 0)
          .toList(),
      pillarHistory: initialHistory,
      missedSessions: 0,
      lastSessionAt: DateTime.now(),
    );

    await _persistProgressSnapshot(_progress!, historyPoints: initialHistory);
  }

  Future<void> _persistInitialTrainingPlan() async {
    final profile = _profile;
    final baseline = _baselineSummary;
    final user = _currentUser;
    if (profile == null || baseline == null || user == null) {
      return;
    }

    _currentPlan = await _createInitialTrainingPlan(
      user: user,
      profile: profile,
      baseline: baseline,
      promptLibrary: promptLibrary,
    );
  }

  Future<TrainingPlan?> _createInitialTrainingPlan({
    required AppUser user,
    required UserProfile profile,
    required CommunicationBaseline baseline,
    required List<PromptTemplate> promptLibrary,
  }) async {
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
                'focus_pillars': item.focusPillars.map(pillarToDb).toList(),
                'difficulty_tier': item.difficultyTier,
                'target_metrics': item.targetMetrics,
                'status': planItemStatusToDb(item.status),
              },
          ],
        },
      },
    )).toString();

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

    return _fetchTrainingPlan(user.id, promptLibrary);
  }

  ProgressSnapshot? _buildRecoveredProgressSnapshot({
    required CommunicationBaseline baseline,
    required List<TrainingSession> sessions,
    required TrainingPlan? currentPlan,
  }) {
    final completed =
        sessions
            .where(
              (session) => session.isCompleted && session.reviews.isNotEmpty,
            )
            .toList()
          ..sort((a, b) {
            final left = a.completedAt ?? a.startedAt;
            final right = b.completedAt ?? b.startedAt;
            return left.compareTo(right);
          });
    if (completed.isEmpty) {
      return null;
    }

    final pillarTotals = <Pillar, double>{
      for (final pillar in Pillar.values) pillar: 0,
    };
    final trend = <double>[];
    final history = <PillarProgressPoint>[];

    for (final session in completed) {
      final review = _bestReviewForSession(session);
      if (review == null) {
        continue;
      }
      trend.add(session.finalScore ?? review.score.overallScore);
      for (final pillar in Pillar.values) {
        pillarTotals[pillar] =
            (pillarTotals[pillar] ?? 0) +
            (review.score.pillarScores[pillar] ?? 0);
      }
    }

    final completedCount = completed.length;
    if (completedCount == 0) {
      return null;
    }

    final averages = <Pillar, double>{
      for (final entry in pillarTotals.entries)
        entry.key: entry.value / completedCount,
    };
    final latestReview = _bestReviewForSession(completed.last);
    if (latestReview == null) {
      return null;
    }

    final overall = AdaptiveEngine.computeOverallFromPillars(averages);
    final coachingAdoptionRate = _coachingAdoptionRateFromSessions(completed);
    final difficultyTolerance = _difficultyToleranceFromSessions(completed);
    final weeklyCompletionRate = _weeklyCompletionRateForPlan(currentPlan);
    final readiness = AdaptiveEngine.computeReadiness(
      normalizedOverall: overall / 100,
      consistency: weeklyCompletionRate,
      coachingAdoption: coachingAdoptionRate,
      difficultyTolerance: difficultyTolerance,
    );
    final level = AdaptiveEngine.assignLevel(
      pillarScores: averages,
      behavior: latestReview.score.behaviorMetrics.copyWith(
        coachingAdoptionRate: coachingAdoptionRate,
        consistency: weeklyCompletionRate,
        difficultyTolerance: difficultyTolerance,
      ),
      overall: overall,
      latestState: RecalibrationState.stable,
    );

    for (final entry in averages.entries) {
      history.add(
        PillarProgressPoint(
          pillar: entry.key,
          score: entry.value,
          recordedOn: baseline.completedAt,
          weekNumber: 0,
        ),
      );
    }

    return ProgressSnapshot(
      currentLevel: level,
      overallScoreEma: overall,
      readinessScore: completed.length <= baselinePrompts.length
          ? baseline.readinessScore
          : readiness,
      currentStreak: _currentStreakFromSessions(completed),
      totalXp: _totalXpFromSessions(completed),
      weeklyCompletionRate: completed.length <= baselinePrompts.length
          ? 1
          : weeklyCompletionRate,
      coachingAdoptionRate: coachingAdoptionRate,
      difficultyTolerance: difficultyTolerance,
      latestRecalibrationState: RecalibrationState.stable,
      pillarScores: averages,
      overallTrend: trend.length > 8 ? trend.sublist(trend.length - 8) : trend,
      pillarHistory: history,
      missedSessions:
          currentPlan?.currentVersion.items
              .where((item) => item.status == PlanItemStatus.missed)
              .length ??
          0,
      lastSessionAt: completed.last.completedAt ?? completed.last.startedAt,
    );
  }

  AttemptReview? _bestReviewForSession(TrainingSession session) {
    if (session.reviews.isEmpty) {
      return null;
    }
    final bestAttemptIndex = (session.bestAttemptNo ?? 1) - 1;
    if (bestAttemptIndex >= 0 && bestAttemptIndex < session.reviews.length) {
      return session.reviews[bestAttemptIndex];
    }
    return session.reviews.last;
  }

  double _coachingAdoptionRateFromSessions(List<TrainingSession> sessions) {
    final reviewed = sessions.where((session) => session.reviews.length > 1);
    if (reviewed.isEmpty) {
      return 0.5;
    }
    final improved = reviewed
        .where((session) => (session.scoreDelta ?? 0) >= 3)
        .length;
    return improved / reviewed.length;
  }

  double _difficultyToleranceFromSessions(List<TrainingSession> sessions) {
    final dailyPlanSessions = sessions
        .where((session) => session.origin == SessionOrigin.dailyPlan)
        .toList();
    if (dailyPlanSessions.isEmpty) {
      return 0.55;
    }

    final highestTier = dailyPlanSessions
        .map((session) => session.prompt.difficultyTier)
        .fold<int>(1, max);
    final highestTierSessions = dailyPlanSessions
        .where((session) => session.prompt.difficultyTier == highestTier)
        .toList();
    if (highestTierSessions.isEmpty) {
      return 0.55;
    }

    final successful = highestTierSessions
        .where((session) => (session.finalScore ?? 0) >= 65)
        .length;
    return successful / highestTierSessions.length;
  }

  double _weeklyCompletionRateForPlan(TrainingPlan? plan) {
    if (plan == null) {
      return 1;
    }

    final weekNumber = _currentWeekNumberForPlan(plan);
    final thisWeek = plan.currentVersion.items
        .where((item) => item.weekNumber == weekNumber)
        .toList();
    if (thisWeek.isEmpty) {
      return 1;
    }

    final completed = thisWeek
        .where((item) => item.status == PlanItemStatus.completed)
        .length;
    return completed / thisWeek.length;
  }

  int _currentStreakFromSessions(List<TrainingSession> sessions) {
    final completed =
        sessions.where((session) => session.completedAt != null).toList()
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

  int _totalXpFromSessions(List<TrainingSession> sessions) {
    var xp = sessions.length * 10;
    xp +=
        sessions.where((session) => (session.scoreDelta ?? 0) >= 3).length * 5;
    return xp;
  }

  int _currentWeekNumberForPlan(TrainingPlan? plan) {
    if (plan == null) {
      return 1;
    }
    return (((DateTime.now().difference(plan.startDate).inDays) ~/ 7) + 1)
        .clamp(1, 10);
  }

  Future<void> _refreshProgressFromCompletedSessions() async {
    final progress = _progress;
    if (progress == null) {
      return;
    }

    final completed = _sessions.where((session) => session.isCompleted).toList()
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
    _weeklyLessonPackets.clear();
  }

  void _publish() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  String get _passwordResetRedirectTo {
    if (kIsWeb) {
      final current = Uri.base;
      return current.replace(query: null, fragment: null).toString();
    }
    return _config.authRedirectUrl;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
