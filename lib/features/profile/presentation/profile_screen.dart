import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(profile.displayName, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('${profile.roleTitle} • ${profile.seniorityBand.label}'),
        const SizedBox(height: 20),
        ShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Training settings', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('Weekly goal: ${profile.weeklyGoalCount} sessions'),
              Text('Preferred mode: ${profile.preferredResponseMode.label}'),
              Text('Timezone: ${profile.timezone}'),
              Text(
                profile.dailyReminderTime.trim().isEmpty
                    ? 'Daily reminder: Off'
                    : 'Daily reminder: ${_formatReminderTime(profile.dailyReminderTime)}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final initial = _parseReminderTime(
                        profile.dailyReminderTime,
                      );
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            initial ?? const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (picked == null) return;
                      final normalized =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      await ref
                          .read(profileRepositoryProvider)
                          .updateDailyReminderTime(normalized);
                    },
                    child: const Text('Set reminder time'),
                  ),
                  if (profile.dailyReminderTime.trim().isNotEmpty)
                    OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(profileRepositoryProvider)
                            .updateDailyReminderTime(null);
                      },
                      child: const Text('Turn off reminder'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final contextValue in profile.communicationContexts)
                    Chip(label: Text(contextValue)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backend status', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                config.useFakeBackend
                    ? 'Demo backend active'
                    : 'Supabase backend active',
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) {
                    context.go('/sign-in');
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TimeOfDay? _parseReminderTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatReminderTime(String value) {
    final time = _parseReminderTime(value);
    if (time == null) {
      return value;
    }
    return DateFormat.jm().format(DateTime(2026, 1, 1, time.hour, time.minute));
  }
}
