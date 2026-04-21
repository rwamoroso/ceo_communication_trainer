import 'package:ceo_communication_trainer/app/providers.dart';
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
    final theme = Theme.of(context);

    if (plan == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final weeks = <int, List<dynamic>>{};
    for (final item in plan.currentVersion.items) {
      weeks.putIfAbsent(item.weekNumber, () => []).add(item);
    }

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
        for (final entry in weeks.entries.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Week ${entry.key}', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (final item in entry.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.drillType),
                      subtitle: Text(
                        DateFormat('EEE, MMM d').format(item.scheduledFor),
                      ),
                      trailing: item.status.name == 'scheduled'
                          ? TextButton(
                              onPressed: () =>
                                  context.go('/plan-item/${item.id}/drill'),
                              child: const Text('Start'),
                            )
                          : Text(item.status.name),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
