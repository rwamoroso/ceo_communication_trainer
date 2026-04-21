import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recalibrations = ref.watch(recalibrationsProvider);
    final progress = ref.watch(progressSnapshotProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly review')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current status', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(progress?.latestRecalibrationState.label ?? 'Stable'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(trainingRepositoryProvider)
                        .generateWeeklyRecalibration();
                  },
                  child: const Text('Run recalibration'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final recalibration in recalibrations)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ShellCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week ${recalibration.weekNumber} • ${recalibration.classification.label}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(recalibration.changesSummary),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final rule in recalibration.ruleHits)
                          Chip(label: Text(rule)),
                      ],
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
