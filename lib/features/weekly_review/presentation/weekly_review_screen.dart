import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recalibrations = ref.watch(recalibrationsProvider);
    final progress = ref.watch(progressSnapshotProvider);
    final plan = ref.watch(currentPlanProvider);
    final theme = Theme.of(context);
    final currentWeek = plan == null
        ? 1
        : (((DateTime.now().difference(plan.startDate).inDays) ~/ 7) + 1)
            .clamp(1, 10);
    final currentWeekPacket = ref.watch(
      weeklyLessonPacketByWeekProvider(currentWeek),
    );

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
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/plan/week/$currentWeek/setup'),
                  child: Text(
                    currentWeekPacket == null
                        ? 'Set up week $currentWeek with AI'
                        : 'Refresh week $currentWeek AI lesson pack',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Return home'),
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
