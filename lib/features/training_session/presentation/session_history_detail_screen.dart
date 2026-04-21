import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionHistoryDetailScreen extends ConsumerWidget {
  const SessionHistoryDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));
    final theme = Theme.of(context);

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(session.prompt.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.prompt.scenarioContext,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(session.prompt.promptText),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < session.attempts.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attempt ${index + 1}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(session.attempts[index].responseText),
                    const SizedBox(height: 12),
                    Text(
                      'Score: ${session.reviews[index].score.overallScore.round()}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Biggest issue: ${session.reviews[index].feedback.biggestIssue}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Next target: ${session.reviews[index].feedback.nextAttemptTarget}',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
