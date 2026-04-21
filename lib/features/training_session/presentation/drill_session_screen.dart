import 'package:ceo_communication_trainer/app/providers.dart';
import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/core/ui/shell_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DrillSessionScreen extends ConsumerStatefulWidget {
  const DrillSessionScreen._({
    this.baselineIndex,
    this.planItemId,
    this.sessionId,
  });

  factory DrillSessionScreen.baseline({required int baselineIndex}) {
    return DrillSessionScreen._(baselineIndex: baselineIndex);
  }

  factory DrillSessionScreen.planItem({required String planItemId}) {
    return DrillSessionScreen._(planItemId: planItemId);
  }

  factory DrillSessionScreen.retry({required String sessionId}) {
    return DrillSessionScreen._(sessionId: sessionId);
  }

  final int? baselineIndex;
  final String? planItemId;
  final String? sessionId;

  @override
  ConsumerState<DrillSessionScreen> createState() => _DrillSessionScreenState();
}

class _DrillSessionScreenState extends ConsumerState<DrillSessionScreen> {
  final _responseController = TextEditingController();
  bool _opening = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSession());
  }

  // Kicks off session creation if it isn't in the session list yet.
  // Build reactively finds the session once it appears in sessionHistoryProvider,
  // so this method doesn't need to set any ID — it just ensures the DB row exists.
  Future<void> _ensureSession() async {
    if (!mounted || _opening) return;
    setState(() => _opening = true);
    try {
      final repository = ref.read(trainingRepositoryProvider);
      await switch ((widget.baselineIndex, widget.planItemId, widget.sessionId)) {
        (final int i, null, null) => repository.openBaselineSession(i),
        (null, final String id, null) => repository.openPlanSession(id),
        (null, null, final String id) => repository.openRetrySession(id),
        _ => throw StateError('Invalid drill route'),
      };
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open drill: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  // Finds the active session from the live session list without relying on a
  // stored ID, so the widget self-heals if a background sync temporarily
  // clears and reloads _sessions.
  TrainingSession? _findSession(List<TrainingSession> sessions) {
    return switch ((widget.baselineIndex, widget.planItemId, widget.sessionId)) {
      (final int i, null, null) => () {
        final prompts = ref.read(trainingRepositoryProvider).baselinePrompts;
        if (i >= prompts.length) return null;
        final promptId = prompts[i].id;
        return sessions
            .where(
              (s) =>
                  s.origin == SessionOrigin.baseline &&
                  s.prompt.id == promptId &&
                  !s.isCompleted,
            )
            .firstOrNull;
      }(),
      (null, final String planItemId, null) => sessions
          .where((s) => s.planItemId == planItemId && !s.isCompleted)
          .firstOrNull,
      (null, null, final String sessionId) =>
        sessions.where((s) => s.id == sessionId).firstOrNull,
      _ => null,
    };
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _submit(TrainingSession session) async {
    if (_responseController.text.trim().split(RegExp(r'\s+')).length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least a few sentences so the coaching has substance.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final profile = ref.read(currentProfileProvider);
      final updated = await ref.read(trainingRepositoryProvider).submitAttempt(
        sessionId: session.id,
        responseText: _responseController.text.trim(),
        responseMode: profile?.preferredResponseMode ?? ResponseMode.typed,
      );
      if (mounted) context.go('/session/${updated.id}/feedback');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionHistoryProvider);
    final session = _findSession(sessions);
    final theme = Theme.of(context);

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lastReview = session.reviews.isNotEmpty ? session.reviews.last : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.origin == SessionOrigin.baseline
              ? 'Baseline drill'
              : 'Daily drill',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ShellCard(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.prompt.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  session.prompt.scenarioContext,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  session.prompt.promptText,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final pillar in session.prompt.activePillars)
                      Chip(label: Text(pillar.label)),
                    Chip(
                      label: Text(
                        '${session.prompt.targetDurationSec}s target',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${session.prompt.targetWordRangeMin}-${session.prompt.targetWordRangeMax} words',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.sessionId != null && lastReview != null)
            ShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Retry target', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(lastReview.feedback.nextAttemptTarget),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ShellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Response draft', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Typed mode is enabled in this scaffold so the scoring loop works end to end before voice capture and transcription are connected.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _responseController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText:
                        'Write the response exactly as you would deliver it. Lead with the answer, use clear structure, and keep it concise.',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : () => _submit(session),
                  child: Text(_submitting ? 'Scoring...' : 'Submit response'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
