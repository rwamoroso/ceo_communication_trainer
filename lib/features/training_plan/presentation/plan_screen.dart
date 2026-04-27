import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(currentPlanProvider);
    final baseline = ref.watch(baselineSummaryProvider);
    final theme = Theme.of(context);

    if (plan == null) {
      if (baseline != null) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('10-week plan', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your baseline is complete, but the training plan is not available yet.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This Supabase project is missing the plan publish function used by the app. '
                    'Apply the latest schema migration, then reopen the app.',
                  ),
                ],
              ),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final weeks = <int, List<PlanItem>>{};
    for (final item in plan.currentVersion.items) {
      weeks.putIfAbsent(item.weekNumber, () => []).add(item);
    }
    final sortedWeekEntries = weeks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in sortedWeekEntries) {
      entry.value.sort((a, b) {
        final dayCompare = a.dayNumber.compareTo(b.dayNumber);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return a.sequenceNumber.compareTo(b.sequenceNumber);
      });
    }
    final currentWeek =
        (((DateTime.now().difference(plan.startDate).inDays) ~/ 7) + 1)
            .clamp(1, 10);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('10-week plan', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          plan.currentVersion.rationaleText,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        for (final entry in sortedWeekEntries.take(7))
          Builder(
            builder: (context) {
              final packet = ref.watch(weeklyLessonPacketByWeekProvider(entry.key));
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ShellCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Week ${entry.key}',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          if (entry.key == currentWeek)
                            const Chip(label: Text('Current week')),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              packet == null ? 'AI setup needed' : 'AI ready',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (packet != null)
                        Text(
                          packet.weeklyObjective,
                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                context.go('/plan/week/${entry.key}/setup'),
                            child: Text(
                              packet == null
                                  ? 'Set up AI lesson pack'
                                  : 'Refresh AI lesson pack',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final item in entry.value)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.drillType),
                          subtitle: Text(
                            DateFormat('EEE, MMM d').format(item.scheduledFor),
                          ),
                          trailing: item.status == PlanItemStatus.scheduled
                              ? TextButton(
                                  onPressed: () => context.go(
                                    packet == null
                                        ? '/plan/week/${entry.key}/setup?nextPlanItemId=${item.id}'
                                        : '/plan-item/${item.id}/drill',
                                  ),
                                  child: Text(
                                    packet == null ? 'Set up AI' : 'Start',
                                  ),
                                )
                              : Text(item.status.label),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
