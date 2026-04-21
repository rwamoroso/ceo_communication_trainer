import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _displayNameController = TextEditingController(text: 'Morgan Lee');
  final _roleTitleController = TextEditingController(text: 'Product Director');
  final _industryController = TextEditingController(text: 'SaaS');
  SeniorityBand _band = SeniorityBand.director;

  @override
  void dispose() {
    _displayNameController.dispose();
    _roleTitleController.dispose();
    _industryController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    try {
      await ref.read(profileRepositoryProvider).saveProfile(
        displayName: _displayNameController.text.trim(),
        roleTitle: _roleTitleController.text.trim(),
        seniorityBand: _band,
        industry: _industryController.text.trim(),
        timezone: DateTime.now().timeZoneName,
      );
      if (mounted) context.go('/onboarding/goals');
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
      appBar: AppBar(title: const Text('Profile setup')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Anchor the training to the actual communication pressure you face.',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          ShellCard(
            child: Column(
              children: [
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _roleTitleController,
                  decoration: const InputDecoration(labelText: 'Role title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SeniorityBand>(
                  initialValue: _band,
                  items: [
                    for (final band in SeniorityBand.values)
                      DropdownMenuItem(value: band, child: Text(band.label)),
                  ],
                  onChanged: (value) => setState(() => _band = value ?? _band),
                  decoration: const InputDecoration(labelText: 'Seniority'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _industryController,
                  decoration: const InputDecoration(labelText: 'Industry'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _continue,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
