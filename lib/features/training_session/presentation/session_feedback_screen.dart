import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionFeedbackScreen extends ConsumerStatefulWidget {
  const SessionFeedbackScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionFeedbackScreen> createState() =>
      _SessionFeedbackScreenState();
}

class _SessionFeedbackScreenState extends ConsumerState<SessionFeedbackScreen> {
  bool _hydrating = false;
  bool _finishing = false;
  String? _hydrateError;
  String? _finishError;
  TrainingSession? _sessionSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSessionLoaded());
  }

  TrainingSession? _preferRicherSession(
    TrainingSession? first,
    TrainingSession? second,
  ) {
    if (first == null) return second;
    if (second == null) return first;

    final firstStrength =
        (first.reviews.length * 1000) +
        (first.attempts.length * 100) +
        (first.isCompleted ? 1 : 0);
    final secondStrength =
        (second.reviews.length * 1000) +
        (second.attempts.length * 100) +
        (second.isCompleted ? 1 : 0);
    return secondStrength >= firstStrength ? second : first;
  }

  Future<void> _ensureSessionLoaded() async {
    if (!mounted || _hydrating) return;

    final existing = _preferRicherSession(
      ref.read(sessionByIdProvider(widget.sessionId)),
      _sessionSnapshot,
    );
    debugPrint(
      'feedback.ensureSessionLoaded session=${widget.sessionId} '
      'existing=${existing != null} reviews=${existing?.reviews.length ?? 0} '
      'attempts=${existing?.attempts.length ?? 0}',
    );

    setState(() {
      _hydrating = true;
      _hydrateError = null;
    });
    try {
      final loaded = await ref
          .read(trainingRepositoryProvider)
          .openRetrySession(widget.sessionId);
      final refreshed = _preferRicherSession(
        ref.read(sessionByIdProvider(widget.sessionId)),
        loaded,
      )!;
      debugPrint(
        'feedback.ensureSessionLoaded.complete session=${widget.sessionId} '
        'reviews=${refreshed.reviews.length} '
        'attempts=${refreshed.attempts.length}',
      );
      if (mounted) {
        setState(() => _sessionSnapshot = refreshed);
      }
    } catch (e) {
      debugPrint(
        'feedback.ensureSessionLoaded.error session=${widget.sessionId} '
        'error=$e',
      );
      if (mounted) {
        setState(() => _hydrateError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _hydrating = false);
      }
    }
  }

  String? _findNextPlanItemId(TrainingSession finishedSession) {
    if (finishedSession.planItemId == null) return null;
    final plan = ref.read(currentPlanProvider);
    if (plan == null) return null;

    final sessions = ref.read(sessionHistoryProvider);
    final completedIds = sessions
        .where((s) => s.isCompleted && s.planItemId != null)
        .map((s) => s.planItemId!)
        .toSet()
      ..add(finishedSession.planItemId!);

    final sorted = [...plan.currentVersion.items]
      ..sort((a, b) {
        final w = a.weekNumber.compareTo(b.weekNumber);
        if (w != 0) return w;
        final d = a.dayNumber.compareTo(b.dayNumber);
        if (d != 0) return d;
        return a.sequenceNumber.compareTo(b.sequenceNumber);
      });

    final currentIndex = sorted.indexWhere(
      (item) => item.id == finishedSession.planItemId,
    );
    if (currentIndex < 0) return null;

    for (var i = currentIndex + 1; i < sorted.length; i++) {
      if (!completedIds.contains(sorted[i].id)) return sorted[i].id;
    }
    return null;
  }

  Future<void> _finishSession(WidgetRef ref) async {
    if (_finishing) return;

    final repository = ref.read(trainingRepositoryProvider);
    final existingSession = _preferRicherSession(
      ref.read(sessionByIdProvider(widget.sessionId)),
      _sessionSnapshot,
    );
    if (existingSession == null) return;

    setState(() {
      _finishing = true;
      _finishError = null;
    });

    try {
      await repository.finalizeSession(widget.sessionId);
      if (!mounted) return;

      if (existingSession.origin == SessionOrigin.baseline) {
        final baseline = repository.baselineSummary;
        if (baseline != null) {
          context.go('/baseline/summary');
          return;
        }

        final prompts = repository.baselinePrompts;
        final completedIds =
            repository.sessions
                .where(
                  (session) =>
                      session.origin == SessionOrigin.baseline &&
                      session.isCompleted,
                )
                .map((session) => session.prompt.id)
                .toSet()
              ..add(existingSession.prompt.id);
        final nextIndex = prompts.indexWhere(
          (prompt) => !completedIds.contains(prompt.id),
        );
        debugPrint(
          'feedback.finishSession baseline session=${widget.sessionId} '
          'completed=${completedIds.length} nextIndex=$nextIndex',
        );
        if (nextIndex < 0 || nextIndex >= prompts.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No remaining baseline drills were found. Returning to baseline intro.',
              ),
            ),
          );
          context.go('/baseline/intro');
          return;
        }
        context.go('/baseline/drill/$nextIndex');
        return;
      }

      final nextId = _findNextPlanItemId(existingSession);
      if (nextId != null) {
        context.go('/plan-item/$nextId/drill');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() => _finishError = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not finish session: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _preferRicherSession(
      ref.watch(sessionByIdProvider(widget.sessionId)),
      _sessionSnapshot,
    );
    final theme = Theme.of(context);

    if (session == null || session.reviews.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session feedback')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hydrating && _hydrateError == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text('Loading feedback...'),
                ] else ...[
                  Text(
                    'Feedback is not available yet for this session.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (_hydrateError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _hydrateError!,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _ensureSessionLoaded,
                    child: const Text('Retry loading feedback'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final review = session.reviews.last;
    final canRetry = session.attempts.length == 1;

    final nextPlanItemId = session.origin == SessionOrigin.dailyPlan
        ? _findNextPlanItemId(session)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session feedback'),
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
                  '${review.score.overallScore.round()} / 100',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  review.feedback.biggestIssue,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text('Secondary issue: ${review.feedback.secondaryIssue}'),
                const SizedBox(height: 8),
                Text('What worked: ${review.feedback.whatWorked}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top coaching points', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final point in review.feedback.topCoachingPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $point'),
                  ),
                const SizedBox(height: 12),
                Text('Improved example', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(review.feedback.improvedExampleAnswer),
                const SizedBox(height: 12),
                Text('Next attempt target', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(review.feedback.nextAttemptTarget),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pillar scores', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final entry in review.score.pillarScores.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.key.label} • ${entry.value.round()}'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: entry.value / 100),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_finishError != null) ...[
            Text(
              _finishError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (canRetry)
            ElevatedButton(
              onPressed: _finishing
                  ? null
                  : () => context.go('/session/${session.id}/retry'),
              child: const Text('Retry once'),
            ),
          if (canRetry) const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _finishing ? null : () => _finishSession(ref),
            child: Text(
              _finishing
                  ? 'Finishing...'
                  : canRetry
                  ? 'Finish session'
                  : nextPlanItemId != null
                  ? 'Next drill'
                  : 'Finish',
            ),
          ),
        ],
      ),
    );
  }
}
