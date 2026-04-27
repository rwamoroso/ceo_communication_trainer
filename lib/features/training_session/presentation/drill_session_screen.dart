import 'dart:async';

import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DrillSessionScreen extends ConsumerStatefulWidget {
  const DrillSessionScreen._({
    this.baselineIndex,
    this.planItemId,
    this.sessionId,
  });

  factory DrillSessionScreen.baseline({required int baselineIndex}) {
    return DrillSessionScreen._(baselineIndex: baselineIndex);
  }

  factory DrillSessionScreen.planItem({required String planItemId}) {
    return DrillSessionScreen._(planItemId: planItemId);
  }

  factory DrillSessionScreen.retry({required String sessionId}) {
    return DrillSessionScreen._(sessionId: sessionId);
  }

  final int? baselineIndex;
  final String? planItemId;
  final String? sessionId;

  @override
  ConsumerState<DrillSessionScreen> createState() => _DrillSessionScreenState();
}

class _DrillSessionScreenState extends ConsumerState<DrillSessionScreen> {
  static final Map<String, String> _draftCache = <String, String>{};

  final _responseController = TextEditingController();
  bool _opening = false;
  bool _submitting = false;
  bool _advancing = false;
  bool _lessonAcknowledged = false;
  String? _openError;
  String? _sessionIdHint;
  TrainingSession? _sessionSnapshot;

  String get _routeIdentity =>
      '${widget.baselineIndex}|${widget.planItemId}|${widget.sessionId}';

  @override
  void initState() {
    super.initState();
    _responseController.text = _draftCache[_routeIdentity] ?? '';
    _responseController.addListener(_handleDraftChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSession());
  }

  @override
  void didUpdateWidget(covariant DrillSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRouteIdentity =
        '${oldWidget.baselineIndex}|${oldWidget.planItemId}|${oldWidget.sessionId}';
    if (oldRouteIdentity == _routeIdentity) {
      return;
    }

    setState(() {
      _openError = null;
      _sessionIdHint = null;
      _sessionSnapshot = null;
      _lessonAcknowledged = false;
    });
    _responseController.text = _draftCache[_routeIdentity] ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSession());
  }

  void _handleDraftChanged() {
    _draftCache[_routeIdentity] = _responseController.text;
  }

  // Kicks off session creation if it isn't in the session list yet.
  // Build reactively finds the session once it appears in sessionHistoryProvider,
  // so this method doesn't need to set any ID — it just ensures the DB row exists.
  Future<void> _ensureSession() async {
    if (!mounted || _opening) return;
    setState(() {
      _opening = true;
      _openError = null;
    });
    try {
      final repository = ref.read(trainingRepositoryProvider);
      final opened =
          await switch ((
            widget.baselineIndex,
            widget.planItemId,
            widget.sessionId,
          )) {
            (final int i, null, null) => () {
              final prompts = repository.baselinePrompts;
              if (i < 0 || i >= prompts.length) {
                throw StateError(
                  'Invalid baseline drill index $i (available: ${prompts.length}).',
                );
              }
              return repository.openBaselineSession(i);
            }(),
            (null, final String id, null) => repository.openPlanSession(id),
            (null, null, final String id) => repository.openRetrySession(id),
            _ => throw StateError('Invalid drill route'),
          }.timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Opening this drill took too long. Please try again.',
            ),
          );
      if (mounted) {
        setState(() {
          _sessionIdHint = opened.id;
          _sessionSnapshot = opened;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _openError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  // Finds the active session from the live session list without relying on a
  // stored ID, so the widget self-heals if a background sync temporarily
  // clears and reloads _sessions.
  TrainingSession? _findSession(List<TrainingSession> sessions) {
    final hintedSession = _sessionIdHint == null
        ? null
        : sessions.where((s) => s.id == _sessionIdHint).firstOrNull;
    if (hintedSession != null) {
      return hintedSession;
    }

    return switch ((
      widget.baselineIndex,
      widget.planItemId,
      widget.sessionId,
    )) {
      (final int i, null, null) => () {
        final prompts = ref.read(trainingRepositoryProvider).baselinePrompts;
        if (i < 0 || i >= prompts.length) return null;
        final promptId = prompts[i].id;
        return sessions
            .where(
              (s) =>
                  s.origin == SessionOrigin.baseline &&
                  s.prompt.id == promptId &&
                  !s.isCompleted,
            )
            .firstOrNull;
      }(),
      (null, final String planItemId, null) =>
        sessions
            .where((s) => s.planItemId == planItemId && !s.isCompleted)
            .firstOrNull,
      (null, null, final String sessionId) =>
        sessions.where((s) => s.id == sessionId).firstOrNull,
      _ => null,
    };
  }

  @override
  void dispose() {
    _responseController.removeListener(_handleDraftChanged);
    _responseController.dispose();
    super.dispose();
  }

  String? _findNextPlanItemId(TrainingSession session) {
    if (session.planItemId == null) return null;
    final plan = ref.read(currentPlanProvider);
    if (plan == null) return null;

    final sessions = ref.read(sessionHistoryProvider);
    final completedIds = sessions
        .where((s) => s.isCompleted && s.planItemId != null)
        .map((s) => s.planItemId!)
        .toSet()
      ..add(session.planItemId!);

    final sorted = [...plan.currentVersion.items]
      ..sort((a, b) {
        final w = a.weekNumber.compareTo(b.weekNumber);
        if (w != 0) return w;
        final d = a.dayNumber.compareTo(b.dayNumber);
        if (d != 0) return d;
        return a.sequenceNumber.compareTo(b.sequenceNumber);
      });

    final currentIndex = sorted.indexWhere((item) => item.id == session.planItemId);
    if (currentIndex < 0) return null;
    for (var i = currentIndex + 1; i < sorted.length; i++) {
      if (!completedIds.contains(sorted[i].id)) return sorted[i].id;
    }
    return null;
  }

  Future<void> _advanceToNext(TrainingSession session) async {
    if (_advancing) return;
    setState(() => _advancing = true);
    try {
      await ref.read(trainingRepositoryProvider).finalizeSession(session.id);
      if (!mounted) return;
      final nextId = _findNextPlanItemId(session);
      context.go(nextId != null ? '/plan-item/$nextId/drill' : '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Future<void> _submit(TrainingSession session) async {
    if (session.attempts.length >= 2) {
      debugPrint(
        'drill.submit.blocked session=${session.id} reason=attempt_limit '
        'attempts=${session.attempts.length}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This session already has two attempts. Opening feedback.',
            ),
          ),
        );
        context.go('/session/${session.id}/feedback');
      }
      return;
    }
    final trimmed = _responseController.text.trim();
    final wordCount = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    if (wordCount < 12) {
      debugPrint(
        'drill.submit.blocked session=${session.id} reason=too_short '
        'wordCount=$wordCount',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add at least a few sentences so the coaching has substance. '
            'Current length: $wordCount words.',
          ),
        ),
      );
      return;
    }
    debugPrint(
      'drill.submit.start session=${session.id} '
      'attempts=${session.attempts.length} wordCount=$wordCount',
    );
    setState(() => _submitting = true);
    try {
      final profile = ref.read(currentProfileProvider);
      final updated = await ref
          .read(trainingRepositoryProvider)
          .submitAttempt(
            sessionId: session.id,
            responseText: trimmed,
            responseMode: profile?.preferredResponseMode ?? ResponseMode.typed,
          );
      _draftCache.remove(_routeIdentity);
      _responseController.clear();
      if (mounted) context.go('/session/${updated.id}/feedback');
    } catch (e) {
      debugPrint('drill.submit.error session=${session.id} error=$e');
      if (e is PostgrestException && e.code == '23514') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This session reached the 2-attempt limit. Opening feedback.',
              ),
            ),
          );
          context.go('/session/${session.id}/feedback');
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionHistoryProvider);
    final session = _findSession(sessions) ?? _sessionSnapshot;
    final theme = Theme.of(context);

    if (session == null) {
      if (_openError != null && !_opening) {
        return Scaffold(
          appBar: AppBar(title: const Text('Drill unavailable')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not open this drill.',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(_openError!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _ensureSession,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!_opening) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSession());
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lastReview = session.reviews.isNotEmpty ? session.reviews.last : null;
    final currentPlan = ref.watch(currentPlanProvider);
    final planItem = session.planItemId == null || currentPlan == null
        ? null
        : currentPlan.currentVersion.items
            .where((item) => item.id == session.planItemId)
            .firstOrNull;
    final weeklyPacket = planItem == null
        ? null
        : ref.watch(weeklyLessonPacketByWeekProvider(planItem.weekNumber));
    final weeklyLesson = session.planItemId == null
        ? null
        : ref.watch(weeklyLessonForPlanItemProvider(session.planItemId!));
    final showLessonPrep =
        session.origin == SessionOrigin.dailyPlan &&
        weeklyPacket != null &&
        weeklyLesson != null &&
        !_lessonAcknowledged;

    if (showLessonPrep) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Weekly drill prep'),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Home',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ShellCard(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weeklyLesson.lessonTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weeklyPacket.weeklyObjective,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(weeklyPacket.developmentSummary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lesson', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(weeklyLesson.lessonBody),
                  const SizedBox(height: 16),
                  Text('What good looks like', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(weeklyLesson.goodExample),
                  const SizedBox(height: 12),
                  Text(
                    'Why it works',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(weeklyLesson.exampleAnalysis),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your development focus',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(weeklyLesson.userDevelopmentFocus),
                  const SizedBox(height: 16),
                  Text(
                    'Pre-drill checklist',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final item in weeklyLesson.preDrillChecklist)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $item'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _lessonAcknowledged = true),
              child: const Text('Continue to drill'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.origin == SessionOrigin.baseline
              ? 'Baseline drill'
              : 'Daily drill',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ShellCard(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.prompt.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  weeklyLesson?.aiScenarioContext ??
                      session.prompt.scenarioContext,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  weeklyLesson?.aiPromptText ?? session.prompt.promptText,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final pillar in session.prompt.activePillars)
                      Chip(label: Text(pillar.label)),
                    Chip(
                      label: Text(
                        '${session.prompt.targetDurationSec}s target',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${session.prompt.targetWordRangeMin}-${session.prompt.targetWordRangeMax} words',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.sessionId != null && lastReview != null)
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Retry target', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(lastReview.feedback.nextAttemptTarget),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Response draft', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Typed mode is enabled in this scaffold so the scoring loop works end to end before voice capture and transcription are connected.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _responseController,
                  maxLines: 10,
                  enabled: session.attempts.length < 2,
                  decoration: const InputDecoration(
                    hintText:
                        'Write the response exactly as you would deliver it. Lead with the answer, use clear structure, and keep it concise.',
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _responseController,
                  builder: (context, value, _) {
                    final text = value.text.trim();
                    final wordCount = text.isEmpty
                        ? 0
                        : text
                            .split(RegExp(r'\s+'))
                            .where((w) => w.isNotEmpty)
                            .length;
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$wordCount words',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  },
                ),
                if (session.attempts.length >= 2) ...[
                  const SizedBox(height: 12),
                  Text(
                    'You have reached the 2-attempt limit for this session. Use feedback to finish and continue.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting || session.attempts.length >= 2
                      ? null
                      : () => _submit(session),
                  child: Text(
                    _submitting
                        ? 'Scoring...'
                        : session.attempts.length >= 2
                        ? 'Attempt limit reached'
                        : 'Submit response',
                  ),
                ),
                if (session.attempts.length >= 2) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        context.go('/session/${session.id}/feedback'),
                    child: const Text('Open feedback'),
                  ),
                ],
                if (session.attempts.isNotEmpty &&
                    session.planItemId != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _advancing ? null : () => _advanceToNext(session),
                    child: Text(_advancing ? 'Moving on...' : 'Next drill'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
