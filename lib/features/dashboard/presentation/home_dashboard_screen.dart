import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:ceo_communication_trainer/core/ui/sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  bool _syncing = false;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(appServiceProvider).reload();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardSnapshotProvider);
    final profile = ref.watch(currentProfileProvider);
    final plan = ref.watch(currentPlanProvider);
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
            ),
            IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              tooltip: 'Sync',
              onPressed: _syncing ? null : _sync,
            ),
          ],
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
              Text('Today\'s drill', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                primaryItem == null
                    ? plan == null
                          ? 'Your baseline is complete, but the published training plan is unavailable in this Supabase project.'
                          : 'You are caught up. Review progress or run the weekly recalibration.'
                    : '${primaryItem.drillType} • focus on ${dashboard.weakestPillar.label.toLowerCase()}',
              ),
              if (primaryItem != null) ...[
                const SizedBox(height: 6),
                Text(DateFormat('EEE, MMM d').format(primaryItem.scheduledFor)),
                if (profile.dailyReminderTime.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Reminder set for ${_formatReminderTime(profile.dailyReminderTime)} local time',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.go('/plan-item/${primaryItem.id}/drill'),
                  child: const Text('Start drill'),
                ),
              ] else if (plan == null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Apply the latest Supabase schema migration, including publish_training_plan_version, then reopen the app.',
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

  String _formatReminderTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return value;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return value;
    }
    return DateFormat.jm().format(DateTime(2026, 1, 1, hour, minute));
  }
}
