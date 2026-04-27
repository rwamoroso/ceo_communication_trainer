import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:ceo_communication_trainer/core/ui/sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressSnapshotProvider);
    final sessions = ref.watch(sessionHistoryProvider);
    final baseline = ref.watch(baselineSummaryProvider);
    final theme = Theme.of(context);

    if (progress == null) {
      if (baseline != null) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Progress', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress data is still being rebuilt.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The app recovered your baseline, but the persisted progress snapshot is still missing. '
                    'Reopen the app after applying the latest Supabase migration if this stays empty.',
                  ),
                ],
              ),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Progress', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        ShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall trend', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Sparkline(values: progress.overallTrend),
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
              for (final entry in progress.pillarScores.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
        ShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent sessions', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final session in sessions.take(6))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(session.prompt.title),
                  subtitle: Text(
                    session.finalScore == null
                        ? 'In progress'
                        : 'Final ${session.finalScore!.round()} • Delta ${session.scoreDelta?.round() ?? 0}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/history/${session.id}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
