import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BaselineSummaryScreen extends ConsumerWidget {
  const BaselineSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseline = ref.watch(baselineSummaryProvider);
    final theme = Theme.of(context);

    if (baseline == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Baseline summary')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            baseline.assignedLevel.label,
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(baseline.summaryText, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Readiness', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: baseline.readinessScore),
                const SizedBox(height: 8),
                Text(
                  '${(baseline.readinessScore * 100).round()}% ready for harder drills',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Strength pillars', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final pillar in baseline.strengthPillars)
                      Chip(label: Text(pillar.label)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Primary focus', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final pillar in baseline.weakPillars)
                      Chip(
                        label: Text(pillar.label),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.15),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Open dashboard'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
