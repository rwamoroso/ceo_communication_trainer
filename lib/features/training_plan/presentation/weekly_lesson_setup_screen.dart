import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WeeklyLessonSetupScreen extends ConsumerStatefulWidget {
  const WeeklyLessonSetupScreen({
    required this.weekNumber,
    this.nextPlanItemId,
    super.key,
  });

  final int weekNumber;
  final String? nextPlanItemId;

  @override
  ConsumerState<WeeklyLessonSetupScreen> createState() =>
      _WeeklyLessonSetupScreenState();
}

class _WeeklyLessonSetupScreenState
    extends ConsumerState<WeeklyLessonSetupScreen> {
  final _importController = TextEditingController();
  bool _loadingPrompt = false;
  bool _importing = false;
  bool _hydratedFromExistingPacket = false;
  String? _prompt;
  String? _promptError;
  String? _importError;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _buildPrompt() async {
    setState(() {
      _loadingPrompt = true;
      _promptError = null;
    });
    try {
      final prompt = await ref
          .read(trainingRepositoryProvider)
          .buildWeeklyLessonPrompt(widget.weekNumber);
      if (!mounted) return;
      setState(() => _prompt = prompt);
    } catch (error) {
      if (!mounted) return;
      setState(() => _promptError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingPrompt = false);
      }
    }
  }

  Future<void> _copyPrompt() async {
    final prompt = _prompt;
    if (prompt == null || prompt.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prompt copied.')));
  }

  Future<void> _importPacket() async {
    setState(() {
      _importing = true;
      _importError = null;
    });
    try {
      await ref
          .read(trainingRepositoryProvider)
          .importWeeklyLessonPacket(
            weekNumber: widget.weekNumber,
            rawJson: _importController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Week ${widget.weekNumber} lesson packet imported.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _importError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = ref.watch(currentPlanProvider);
    final packet = ref.watch(
      weeklyLessonPacketByWeekProvider(widget.weekNumber),
    );
    final weekItems = plan?.currentVersion.items
        .where((item) => item.weekNumber == widget.weekNumber)
        .toList();
    weekItems?.sort((a, b) {
      final dayCompare = a.dayNumber.compareTo(b.dayNumber);
      if (dayCompare != 0) {
        return dayCompare;
      }
      return a.sequenceNumber.compareTo(b.sequenceNumber);
    });

    if (!_hydratedFromExistingPacket &&
        packet != null &&
        _importController.text.trim().isEmpty) {
      _importController.text = packet.rawImportText;
      _hydratedFromExistingPacket = true;
    }

    if (plan == null || weekItems == null || weekItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Week lesson setup')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This week is not available in the current plan.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Week ${widget.weekNumber} question pack')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lesson packet status', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  packet == null
                      ? 'No lesson packet yet. Build a copy/paste prompt, run it in your AI tool, and import the JSON question pack for next week.'
                      : 'Imported and ready for this week.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: _loadingPrompt ? null : _buildPrompt,
                      child: Text(
                        _loadingPrompt
                            ? 'Building prompt...'
                            : 'Build AI question prompt',
                      ),
                    ),
                    if (_prompt != null)
                      OutlinedButton(
                        onPressed: _copyPrompt,
                        child: const Text('Copy prompt'),
                      ),
                    OutlinedButton(
                      onPressed: () => context.go('/plan'),
                      child: const Text('Return to plan'),
                    ),
                    if (packet != null && widget.nextPlanItemId != null)
                      OutlinedButton(
                        onPressed: () => context.go(
                          '/plan-item/${widget.nextPlanItemId}/drill',
                        ),
                        child: const Text('Open drill'),
                      ),
                  ],
                ),
                if (packet != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Imported ${packet.updatedAt.toLocal()}',
                    style: theme.textTheme.bodySmall,
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
                Text('This week\'s drills', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final item in weekItems)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Day ${item.dayNumber} • ${item.drillType}'),
                    subtitle: Text(
                      'Plan item ${item.id} • difficulty ${item.difficultyTier}',
                    ),
                  ),
              ],
            ),
          ),
          if (_promptError != null) ...[
            const SizedBox(height: 16),
            Text(
              _promptError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_prompt != null) ...[
            const SizedBox(height: 16),
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI question prompt', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const Text(
                    'Copy this prompt into your AI tool to generate next week\'s personalized drill questions and lesson packet.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(_prompt!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manual JSON import', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Paste the strict JSON response from your AI tool here. The app validates the lesson packet, including the exact drill questions for the coming week, before saving it.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _importController,
                  maxLines: 18,
                  decoration: const InputDecoration(
                    hintText:
                        '{\n  "week_number": 1,\n  "weekly_objective": "..."\n}',
                  ),
                ),
                if (_importError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _importError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _importing ? null : _importPacket,
                  child: Text(
                    _importing ? 'Importing...' : 'Import lesson packet',
                  ),
                ),
              ],
            ),
          ),
          if (packet != null) ...[
            const SizedBox(height: 16),
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Imported summary', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    packet.weeklyObjective,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(packet.developmentSummary),
                  if (packet.previousWeekAnalysis.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Previous week analysis',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(packet.previousWeekAnalysis),
                  ],
                  if (packet.previousWeekEvaluations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'AI session scores',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final eval in packet.previousWeekEvaluations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                eval.keyObservations.isNotEmpty
                                    ? eval.keyObservations.first
                                    : eval.sessionId,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${eval.aiScore.round()} / 100',
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Text('${packet.drills.length} drill lessons ready'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
