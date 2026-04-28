import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';

class DrillGuidance {
  static String purposeFor({
    required PromptTemplate prompt,
    WeeklyDrillLesson? lesson,
  }) {
    final explicit = lesson?.drillPurpose.trim() ?? '';
    if (explicit.isNotEmpty) {
      return explicit;
    }

    return switch (prompt.category) {
      PromptCategory.blufStructuredThinking =>
        'Train answer-first updates that land clearly before details.',
      PromptCategory.directAnswerDiscipline =>
        'Train direct answers so the recommendation lands in the opening sentence.',
      PromptCategory.brevityCompression =>
        'Train tighter executive updates that keep only decision-relevant detail.',
      PromptCategory.executivePresence =>
        'Train calm, credible delivery that sounds decisive under scrutiny.',
      PromptCategory.strategicFraming =>
        'Train strategic framing that names the decision, tradeoff, and business impact.',
      PromptCategory.pressureResponse =>
        'Train concise pressure handling with clear immediate action and ownership.',
      PromptCategory.listeningSummarization =>
        'Train concise summaries that synthesize what matters and end with a recommendation.',
    };
  }

  static List<String> successSignalsFor({
    required PromptTemplate prompt,
    WeeklyDrillLesson? lesson,
  }) {
    final explicit =
        lesson?.successSignals
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final signals = <String>[
      'Lead with the answer in the first sentence.',
      'Keep the response to ${prompt.targetWordRangeMin}-${prompt.targetWordRangeMax} words.',
      'Use a simple structure with no more than three supporting points.',
    ];

    switch (prompt.category) {
      case PromptCategory.strategicFraming:
        signals[1] = 'Name the decision, key tradeoff, and business impact.';
      case PromptCategory.pressureResponse:
        signals[1] = 'State the immediate action, owner, and risk control.';
      case PromptCategory.listeningSummarization:
        signals[1] =
            'Summarize the key signal before giving the recommendation.';
      case PromptCategory.executivePresence:
        signals[2] = 'Use crisp, decisive language without filler or apology.';
      case PromptCategory.brevityCompression:
        signals[2] =
            'Cut setup so only the headline and essential support remain.';
      case PromptCategory.blufStructuredThinking:
      case PromptCategory.directAnswerDiscipline:
        break;
    }

    return signals;
  }
}
