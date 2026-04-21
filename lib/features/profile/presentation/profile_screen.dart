import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
}
