import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionFeedbackScreen extends ConsumerWidget {
  const SessionFeedbackScreen({required this.sessionId, super.key});

  final String sessionId;

  Future<void> _finishSession(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(trainingRepositoryProvider);
    final existingSession = ref.read(sessionByIdProvider(sessionId));
    if (existingSession == null) return;

    await repository.finalizeSession(sessionId);

    if (existingSession.origin == SessionOrigin.baseline) {
      final baseline = ref.read(baselineSummaryProvider);
      if (baseline != null) {
        if (context.mounted) {
          context.go('/baseline/summary');
        }
        return;
      }

      final prompts = repository.baselinePrompts;
      final completedIds = ref
          .read(sessionHistoryProvider)
          .where(
            (session) =>
                session.origin == SessionOrigin.baseline && session.isCompleted,
          )
          .map((session) => session.prompt.id)
          .toSet();
      final nextIndex = prompts.indexWhere(
        (prompt) => !completedIds.contains(prompt.id),
      );
      if (context.mounted) {
        context.go('/baseline/drill/$nextIndex');
      }
      return;
    }

    if (context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));
    final theme = Theme.of(context);

    if (session == null || session.reviews.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final review = session.reviews.last;
    final canRetry = session.attempts.length == 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Session feedback')),
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
          if (canRetry)
            ElevatedButton(
              onPressed: () => context.go('/session/${session.id}/retry'),
              child: const Text('Retry once'),
            ),
          if (canRetry) const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _finishSession(context, ref),
            child: Text(canRetry ? 'Finish session' : 'Continue'),
          ),
        ],
      ),
    );
  }
}
