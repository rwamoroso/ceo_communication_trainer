import 'dart:math';

import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';

class ScoredAttempt {
  const ScoredAttempt({required this.score, required this.feedback});

  final SessionScore score;
  final SessionFeedback feedback;
}

class ScoringEngine {
  static const _fillerWords = {
    'um',
    'uh',
    'like',
    'you know',
    'basically',
    'actually',
    'sort of',
    'kind of',
  };

  static ScoredAttempt evaluate({
    required PromptTemplate prompt,
    required String responseText,
    required ResponseMode responseMode,
    SessionAttempt? previousAttempt,
  }) {
    final cleanedText = responseText.trim();
    final words = _words(cleanedText);
    final wordCount = max(words.length, 1);
    final durationSeconds = responseMode == ResponseMode.typed
        ? max(prompt.targetDurationSec - 5, (wordCount / 140 * 60).round())
        : prompt.targetDurationSec;
    final lowerText = cleanedText.toLowerCase();

    final answerFirst = _startsWithAnswer(lowerText);
    final earlyAnswer = _mentionsAnswerEarly(words);
    final structured = _hasThreePointStructure(lowerText);
    final strategicLanguage = _containsAny(lowerText, [
      'risk',
      'tradeoff',
      'impact',
      'recommend',
      'decision',
      'option',
    ]);
    final pressureLanguage = _containsAny(lowerText, [
      'immediately',
      'now',
      'mitigate',
      'escalate',
      'contain',
      'next step',
    ]);
    final conciseScore = _lengthBandScore(
      wordCount,
      prompt.targetWordRangeMin,
      prompt.targetWordRangeMax,
    );
    final fillerWordsPerMinute = responseMode == ResponseMode.audio
        ? _fillerWordsPerMinute(lowerText, durationSeconds)
        : null;

    final behavior = BehaviorMetrics(
      directAnswerRate: answerFirst ? 1 : (earlyAnswer ? 0.72 : 0.34),
      blufUsageRate: answerFirst ? 0.9 : (earlyAnswer ? 0.55 : 0.22),
      cleanThreePointStructureRate: structured ? 0.9 : 0.36,
      fillerWordsPerMinute: fillerWordsPerMinute,
      averageResponseLengthWords: wordCount.toDouble(),
      wordsPerMinute: responseMode == ResponseMode.audio
          ? wordCount / max(durationSeconds / 60, 0.1)
          : null,
    );

    final pillarScores = <Pillar, double>{
      Pillar.clarity: _clampScore(
        behavior.directAnswerRate * 38 +
            behavior.blufUsageRate * 26 +
            conciseScore * 20 +
            (structured ? 16 : 6),
      ),
      Pillar.structure: _clampScore(
        behavior.cleanThreePointStructureRate * 58 +
            behavior.blufUsageRate * 14 +
            (structured ? 18 : 5) +
            (answerFirst ? 10 : 4),
      ),
      Pillar.brevity: _clampScore(
        conciseScore * 70 + behavior.directAnswerRate * 30,
      ),
      Pillar.presence: _clampScore(
        42 +
            conciseScore * 26 +
            behavior.cleanThreePointStructureRate * 18 +
            behavior.directAnswerRate * 14 -
            ((fillerWordsPerMinute ?? 0) * 2),
      ),
      Pillar.strategicFraming: _clampScore(
        (strategicLanguage ? 62 : 38) +
            behavior.directAnswerRate * 18 +
            behavior.cleanThreePointStructureRate * 20,
      ),
      Pillar.pressureResponse: _clampScore(
        (pressureLanguage ? 64 : 40) +
            behavior.directAnswerRate * 16 +
            behavior.cleanThreePointStructureRate * 20,
      ),
    };

    final overall = prompt.pillarWeights.entries.fold<double>(
      0,
      (sum, entry) => sum + (pillarScores[entry.key] ?? 0) * entry.value,
    );

    final issues = _rankIssues(
      prompt: prompt,
      behavior: behavior,
      pillarScores: pillarScores,
      conciseScore: conciseScore,
    );
    final biggest = issues.first;
    final secondary = issues.length > 1
        ? issues[1]
        : 'Push for tighter polish.';

    final strongestPillar = pillarScores.entries.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );

    final feedback = SessionFeedback(
      biggestIssue: biggest,
      secondaryIssue: secondary,
      whatWorked:
          'Your strongest signal was ${strongestPillar.key.label.toLowerCase()}.',
      topCoachingPoints: _coachingPoints(prompt.category, issues),
      improvedExampleAnswer: _improvedExample(prompt.category),
      nextAttemptTarget: _nextTarget(biggest),
    );

    return ScoredAttempt(
      score: SessionScore(
        overallScore: _clampScore(overall),
        pillarScores: pillarScores,
        behaviorMetrics: behavior.copyWith(
          retryCount: previousAttempt == null ? 0 : 1,
        ),
      ),
      feedback: feedback,
    );
  }

  static List<String> _coachingPoints(
    PromptCategory category,
    List<String> issues,
  ) {
    final points = <String>[
      'Lead with the answer in your opening sentence.',
      'Use a clear 3-point structure.',
      'Cut any setup that does not change the recommendation.',
    ];

    if (category == PromptCategory.strategicFraming) {
      points[1] = 'Name the decision, tradeoff, and business impact.';
    }
    if (category == PromptCategory.pressureResponse) {
      points[2] = 'State the immediate action, owner, and risk control.';
    }

    if (issues.first.contains('structure')) {
      points[1] = 'Use exactly three short points with clean labels.';
    }

    return points.take(3).toList();
  }

  static String _improvedExample(PromptCategory category) => switch (category) {
    PromptCategory.blufStructuredThinking =>
      'My recommendation is to reset the timeline by one week. First, it protects quality. Second, it avoids rework. Third, it keeps leadership trust intact.',
    PromptCategory.directAnswerDiscipline =>
      'Yes, we should move forward. The reason is speed, the risk is manageable, and the next step is to brief the team today.',
    PromptCategory.brevityCompression =>
      'The update is simple: we are on track, one dependency is at risk, and I need one decision by Friday.',
    PromptCategory.executivePresence =>
      'The headline is that the launch can hold if we narrow scope. I recommend cutting two low-value features and protecting the core customer flow.',
    PromptCategory.strategicFraming =>
      'I recommend option B because it improves margin, limits execution risk, and still protects the customer experience.',
    PromptCategory.pressureResponse =>
      'The immediate move is to contain the issue, assign one owner, and update leadership every two hours until risk is back under control.',
    PromptCategory.listeningSummarization =>
      'Here is the summary: the customer wants speed, pricing clarity, and one accountable owner. My recommendation is to confirm scope today and send a revised plan by tomorrow.',
  };

  static String _nextTarget(String biggestIssue) {
    if (biggestIssue.contains('answer')) {
      return 'State the recommendation in the first sentence.';
    }
    if (biggestIssue.contains('structure')) {
      return 'Use a clean three-part answer with labeled points.';
    }
    if (biggestIssue.contains('long')) {
      return 'Keep the full response inside the target word band.';
    }
    return 'Tighten the answer and make the next step explicit.';
  }

  static List<String> _rankIssues({
    required PromptTemplate prompt,
    required BehaviorMetrics behavior,
    required Map<Pillar, double> pillarScores,
    required double conciseScore,
  }) {
    final issues = <String>[];

    if (behavior.directAnswerRate < 0.7) {
      issues.add('You delayed the answer instead of leading with it.');
    }
    if (behavior.cleanThreePointStructureRate < 0.6) {
      issues.add('Your structure was hard to follow.');
    }
    if (conciseScore < 0.6) {
      issues.add('Your response ran too long for an executive update.');
    }
    if (prompt.category == PromptCategory.strategicFraming &&
        (pillarScores[Pillar.strategicFraming] ?? 0) < 60) {
      issues.add('You described the situation, but not the decision tradeoff.');
    }
    if (prompt.category == PromptCategory.pressureResponse &&
        (pillarScores[Pillar.pressureResponse] ?? 0) < 60) {
      issues.add('Your pressure response needed a clearer immediate action.');
    }

    if (issues.isEmpty) {
      issues.add('Your answer was solid, but it can be even sharper.');
      issues.add('Push for tighter executive tone and cleaner finish.');
    }

    return issues;
  }

  static bool _startsWithAnswer(String text) {
    const cues = [
      'my recommendation is',
      'i recommend',
      'the answer is',
      'yes,',
      'no,',
      'we should',
      'the headline is',
      'bottom line',
    ];
    return cues.any(text.startsWith);
  }

  static bool _mentionsAnswerEarly(List<String> words) {
    final earlyWindow = words
        .take(max((words.length * 0.2).ceil(), 1))
        .join(' ');
    return _containsAny(earlyWindow, [
      'recommend',
      'should',
      'answer',
      'headline',
      'bottom line',
      'yes',
      'no',
    ]);
  }

  static bool _hasThreePointStructure(String text) {
    const patterns = [
      'first',
      'second',
      'third',
      '1.',
      '2.',
      '3.',
      'one,',
      'two,',
      'three,',
    ];
    var hits = 0;
    for (final pattern in patterns) {
      if (text.contains(pattern)) {
        hits++;
      }
    }
    return hits >= 2;
  }

  static bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }

  static List<String> _words(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
  }

  static double _lengthBandScore(int count, int minWords, int maxWords) {
    if (count >= minWords && count <= maxWords) {
      return 1;
    }
    if (count < minWords) {
      return max(0.35, count / minWords);
    }
    final overflow = count - maxWords;
    return max(0.2, 1 - (overflow / max(maxWords.toDouble(), 1)));
  }

  static double? _fillerWordsPerMinute(String text, int durationSeconds) {
    var count = 0;
    for (final filler in _fillerWords) {
      if (text.contains(filler)) {
        count += filler.split(' ').length;
      }
    }
    final minutes = max(durationSeconds / 60, 0.1);
    return count / minutes;
  }

  static double _clampScore(double value) {
    return value.clamp(0, 100).toDouble();
  }
}
