import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:ceo_communication_trainer/services/demo/prompt_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GoalsContextsScreen extends ConsumerStatefulWidget {
  const GoalsContextsScreen({super.key});

  @override
  ConsumerState<GoalsContextsScreen> createState() =>
      _GoalsContextsScreenState();
}

class _GoalsContextsScreenState extends ConsumerState<GoalsContextsScreen> {
  final _selectedContexts = <String>{seededContexts.first, seededContexts[2]};
  final _selectedGoals = <String>{seededGoals.first, seededGoals[1]};
  double _weeklyGoalCount = 5;
  bool _microphoneConsent = false;
  ResponseMode _responseMode = ResponseMode.typed;

  Future<void> _finish() async {
    try {
      await ref.read(profileRepositoryProvider).completeOnboarding(
        weeklyGoalCount: _weeklyGoalCount.round(),
        communicationContexts: _selectedContexts.toList(),
        goals: _selectedGoals.toList(),
        microphoneConsent: _microphoneConsent,
        preferredResponseMode: _responseMode,
      );
      if (mounted) context.go('/baseline/intro');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals and contexts')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where do you need sharper communication?',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final contextValue in seededContexts)
                      FilterChip(
                        label: Text(contextValue),
                        selected: _selectedContexts.contains(contextValue),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedContexts.add(contextValue);
                            } else {
                              _selectedContexts.remove(contextValue);
                            }
                          });
                        },
                      ),
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
                Text(
                  'What should improve first?',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final goal in seededGoals)
                      FilterChip(
                        label: Text(goal),
                        selected: _selectedGoals.contains(goal),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedGoals.add(goal);
                            } else {
                              _selectedGoals.remove(goal);
                            }
                          });
                        },
                      ),
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
                Text(
                  'Cadence and response mode',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Weekly drill target: ${_weeklyGoalCount.round()}'),
                Slider(
                  min: 3,
                  max: 7,
                  divisions: 4,
                  value: _weeklyGoalCount,
                  onChanged: (value) =>
                      setState(() => _weeklyGoalCount = value),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ResponseMode>(
                  segments: const [
                    ButtonSegment(
                      value: ResponseMode.typed,
                      label: Text('Typed'),
                      icon: Icon(Icons.keyboard_outlined),
                    ),
                    ButtonSegment(
                      value: ResponseMode.audio,
                      label: Text('Audio'),
                      icon: Icon(Icons.mic_none_rounded),
                    ),
                  ],
                  selected: {_responseMode},
                  onSelectionChanged: (selection) {
                    setState(() => _responseMode = selection.first);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _microphoneConsent,
                  onChanged: (value) =>
                      setState(() => _microphoneConsent = value),
                  title: const Text(
                    'Allow microphone capture when audio mode is available',
                  ),
                ),
                ElevatedButton(
                  onPressed: _finish,
                  child: const Text('Start baseline'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
