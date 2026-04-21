import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BaselineIntroScreen extends ConsumerWidget {
  const BaselineIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = ref.watch(trainingRepositoryProvider).baselinePrompts;
    final theme = Theme.of(context);
    final hasPrompts = prompts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Baseline assessment')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Seven short drills will set your current level, weak pillars, and first 10-week plan.',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What the assessment measures',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < prompts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${i + 1}. ${prompts[i].title} • ${prompts[i].category.label}',
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  hasPrompts
                      ? 'Each drill follows the same loop: prompt, response, coaching, retry, score delta.'
                      : 'No baseline prompts are available yet. Apply the Supabase prompt seed migration before starting the live backend.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: hasPrompts
                      ? () => context.go('/baseline/drill/0')
                      : null,
                  child: const Text('Start drill 1'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
