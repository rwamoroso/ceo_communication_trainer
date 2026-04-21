import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:ceo_communication_trainer/core/ui/sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardSnapshotProvider);
    final profile = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    if (dashboard == null || profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final primaryItem = dashboard.todayItems.isNotEmpty
        ? dashboard.todayItems.first
        : (dashboard.upcomingItems.isNotEmpty
              ? dashboard.upcomingItems.first
              : null);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Welcome back, ${profile.displayName.split(' ').first}.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${dashboard.currentLevel.label} • ${(dashboard.readinessScore * 100).round()}% readiness',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        ShellCard(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This week', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(theme, '${dashboard.streak}', 'Streak'),
                  const SizedBox(width: 12),
                  _stat(theme, dashboard.thisWeeksStatus.label, 'Status'),
                  const SizedBox(width: 12),
                  _stat(
                    theme,
                    '+${dashboard.latestImprovement.round()}',
                    'Latest delta',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Sparkline(values: dashboard.progress.overallTrend),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s best next move',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                primaryItem == null
                    ? 'You are caught up. Review progress or run the weekly recalibration.'
                    : '${primaryItem.drillType} • focus on ${dashboard.weakestPillar.label.toLowerCase()}',
              ),
              if (primaryItem != null) ...[
                const SizedBox(height: 6),
                Text(DateFormat('EEE, MMM d').format(primaryItem.scheduledFor)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.go('/plan-item/${primaryItem.id}/drill'),
                  child: const Text('Start drill'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upcoming drills', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final item in dashboard.upcomingItems.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.drillType),
                  subtitle: Text(
                    DateFormat('EEE, MMM d').format(item.scheduledFor),
                  ),
                  trailing: Text('Tier ${item.difficultyTier}'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.go('/weekly-review'),
                child: const Text('Open weekly review'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(ThemeData theme, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.titleLarge),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
