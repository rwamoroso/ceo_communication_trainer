import 'package:ceo_communication_trainer/core/types/app_models.dart';
import 'package:ceo_communication_trainer/core/types/app_types.dart';

const seededContexts = [
  'Executive updates',
  'Decision recommendations',
  'Cross-functional alignment',
  'Escalations',
  'Board / leadership prep',
  'Customer issue response',
];

const seededGoals = [
  'Get to the point faster',
  'Sound more executive',
  'Handle pressure cleanly',
  'Summarize meetings sharply',
  'Recommend with stronger logic',
  'Cut filler and overexplaining',
];

final seededPrompts = <PromptTemplate>[
  PromptTemplate(
    id: 'baseline-bluf',
    slug: 'baseline-bluf',
    title: 'Status update with BLUF',
    category: PromptCategory.blufStructuredThinking,
    difficultyTier: 1,
    scenarioContext: 'Your CEO asks for a quick update on a delayed launch.',
    promptText:
        'Give a 45-second update with the answer first, then the three most important points, then the ask.',
    targetDurationSec: 45,
    targetWordRangeMin: 70,
    targetWordRangeMax: 105,
    pillarWeights: {
      Pillar.clarity: 0.4,
      Pillar.structure: 0.4,
      Pillar.brevity: 0.2,
    },
    behaviorTargets: {'direct_answer_rate': 0.8, 'bluf_usage_rate': 0.8},
  ),
  PromptTemplate(
    id: 'baseline-direct',
    slug: 'baseline-direct',
    title: 'Direct answer discipline',
    category: PromptCategory.directAnswerDiscipline,
    difficultyTier: 1,
    scenarioContext:
        'A VP asks whether the team should pause a feature launch.',
    promptText:
        'Answer yes or no immediately, give your recommendation, and explain only the most important reasoning.',
    targetDurationSec: 35,
    targetWordRangeMin: 45,
    targetWordRangeMax: 80,
    pillarWeights: {
      Pillar.clarity: 0.5,
      Pillar.brevity: 0.3,
      Pillar.structure: 0.2,
    },
    behaviorTargets: {'direct_answer_rate': 0.9, 'response_length_words': 70},
  ),
  PromptTemplate(
    id: 'baseline-brevity',
    slug: 'baseline-brevity',
    title: 'Compression under constraint',
    category: PromptCategory.brevityCompression,
    difficultyTier: 1,
    scenarioContext: 'You have 30 seconds at the end of a leadership meeting.',
    promptText:
        'Summarize the update in under 30 seconds without losing the key recommendation.',
    targetDurationSec: 30,
    targetWordRangeMin: 35,
    targetWordRangeMax: 55,
    pillarWeights: {
      Pillar.brevity: 0.5,
      Pillar.clarity: 0.3,
      Pillar.structure: 0.2,
    },
    behaviorTargets: {'response_length_words': 50, 'bluf_usage_rate': 0.7},
  ),
  PromptTemplate(
    id: 'baseline-presence',
    slug: 'baseline-presence',
    title: 'Executive presence',
    category: PromptCategory.executivePresence,
    difficultyTier: 1,
    scenarioContext:
        'A senior leader pushes back on your proposal in a meeting.',
    promptText:
        'Respond calmly, keep ownership, and restate the recommendation with confident economy.',
    targetDurationSec: 45,
    targetWordRangeMin: 55,
    targetWordRangeMax: 90,
    pillarWeights: {
      Pillar.presence: 0.45,
      Pillar.clarity: 0.3,
      Pillar.brevity: 0.25,
    },
    behaviorTargets: {'filler_words_per_minute': 4, 'direct_answer_rate': 0.75},
  ),
  PromptTemplate(
    id: 'baseline-pressure',
    slug: 'baseline-pressure',
    title: 'Pressure response',
    category: PromptCategory.pressureResponse,
    difficultyTier: 2,
    scenarioContext: 'A production outage affects a top-tier customer.',
    promptText:
        'Deliver the immediate response plan, risk framing, and next update cadence.',
    targetDurationSec: 50,
    targetWordRangeMin: 65,
    targetWordRangeMax: 100,
    pillarWeights: {
      Pillar.pressureResponse: 0.45,
      Pillar.structure: 0.3,
      Pillar.clarity: 0.25,
    },
    behaviorTargets: {
      'direct_answer_rate': 0.8,
      'clean_three_point_structure_rate': 0.7,
    },
  ),
  PromptTemplate(
    id: 'baseline-strategy',
    slug: 'baseline-strategy',
    title: 'Strategic framing',
    category: PromptCategory.strategicFraming,
    difficultyTier: 2,
    scenarioContext: 'The company must choose between two expansion bets.',
    promptText:
        'Recommend one option, explain the tradeoff, and tie it to business impact.',
    targetDurationSec: 60,
    targetWordRangeMin: 80,
    targetWordRangeMax: 120,
    pillarWeights: {
      Pillar.strategicFraming: 0.45,
      Pillar.clarity: 0.25,
      Pillar.structure: 0.3,
    },
    behaviorTargets: {'bluf_usage_rate': 0.8, 'direct_answer_rate': 0.8},
  ),
  PromptTemplate(
    id: 'baseline-summary',
    slug: 'baseline-summary',
    title: 'Listening and summarization',
    category: PromptCategory.listeningSummarization,
    difficultyTier: 1,
    scenarioContext:
        'A customer call ends with multiple asks and one hidden risk.',
    promptText:
        'Summarize the call in a crisp executive readout with decisions, risks, and next steps.',
    targetDurationSec: 50,
    targetWordRangeMin: 65,
    targetWordRangeMax: 95,
    pillarWeights: {
      Pillar.clarity: 0.4,
      Pillar.structure: 0.4,
      Pillar.brevity: 0.2,
    },
    behaviorTargets: {
      'clean_three_point_structure_rate': 0.8,
      'direct_answer_rate': 0.75,
    },
  ),
  PromptTemplate(
    id: 'plan-1',
    slug: 'plan-1',
    title: 'Recommendation with three reasons',
    category: PromptCategory.directAnswerDiscipline,
    difficultyTier: 1,
    scenarioContext: 'A leader asks whether to prioritize speed or polish.',
    promptText:
        'Give the recommendation immediately and support it with three short reasons.',
    targetDurationSec: 40,
    targetWordRangeMin: 55,
    targetWordRangeMax: 85,
    pillarWeights: {
      Pillar.clarity: 0.45,
      Pillar.structure: 0.3,
      Pillar.brevity: 0.25,
    },
    behaviorTargets: {'direct_answer_rate': 0.85},
  ),
  PromptTemplate(
    id: 'plan-2',
    slug: 'plan-2',
    title: 'Condense the update',
    category: PromptCategory.brevityCompression,
    difficultyTier: 1,
    scenarioContext: 'You get one minute in a staff meeting.',
    promptText: 'Compress the update into headline, risk, and ask.',
    targetDurationSec: 30,
    targetWordRangeMin: 35,
    targetWordRangeMax: 55,
    pillarWeights: {
      Pillar.brevity: 0.45,
      Pillar.clarity: 0.35,
      Pillar.structure: 0.2,
    },
    behaviorTargets: {'response_length_words': 50},
  ),
  PromptTemplate(
    id: 'plan-3',
    slug: 'plan-3',
    title: 'Executive pushback',
    category: PromptCategory.executivePresence,
    difficultyTier: 2,
    scenarioContext:
        'An executive challenges your numbers in front of the room.',
    promptText:
        'Respond with calm ownership, keep the answer short, and offer the next step.',
    targetDurationSec: 45,
    targetWordRangeMin: 55,
    targetWordRangeMax: 85,
    pillarWeights: {
      Pillar.presence: 0.45,
      Pillar.clarity: 0.3,
      Pillar.structure: 0.25,
    },
    behaviorTargets: {'filler_words_per_minute': 4},
  ),
  PromptTemplate(
    id: 'plan-4',
    slug: 'plan-4',
    title: 'Incident escalation',
    category: PromptCategory.pressureResponse,
    difficultyTier: 2,
    scenarioContext: 'A vendor failure may impact revenue this quarter.',
    promptText:
        'Give the escalation summary, immediate action, and executive ask.',
    targetDurationSec: 50,
    targetWordRangeMin: 65,
    targetWordRangeMax: 100,
    pillarWeights: {
      Pillar.pressureResponse: 0.45,
      Pillar.structure: 0.3,
      Pillar.clarity: 0.25,
    },
    behaviorTargets: {'direct_answer_rate': 0.8},
  ),
  PromptTemplate(
    id: 'plan-5',
    slug: 'plan-5',
    title: 'Strategic recommendation memo',
    category: PromptCategory.strategicFraming,
    difficultyTier: 3,
    scenarioContext: 'Leadership is split between growth and margin.',
    promptText:
        'Recommend one path, name the tradeoff, and tie it to business impact.',
    targetDurationSec: 60,
    targetWordRangeMin: 85,
    targetWordRangeMax: 120,
    pillarWeights: {
      Pillar.strategicFraming: 0.5,
      Pillar.clarity: 0.2,
      Pillar.structure: 0.3,
    },
    behaviorTargets: {'bluf_usage_rate': 0.8},
  ),
  PromptTemplate(
    id: 'plan-6',
    slug: 'plan-6',
    title: 'Meeting summary for a VP',
    category: PromptCategory.listeningSummarization,
    difficultyTier: 2,
    scenarioContext:
        'A long cross-functional meeting ended with unclear ownership.',
    promptText:
        'Summarize what matters, what changed, and who owns the next move.',
    targetDurationSec: 45,
    targetWordRangeMin: 55,
    targetWordRangeMax: 90,
    pillarWeights: {
      Pillar.clarity: 0.35,
      Pillar.structure: 0.45,
      Pillar.brevity: 0.2,
    },
    behaviorTargets: {'clean_three_point_structure_rate': 0.8},
  ),
  PromptTemplate(
    id: 'plan-7',
    slug: 'plan-7',
    title: 'BLUF with escalation',
    category: PromptCategory.blufStructuredThinking,
    difficultyTier: 2,
    scenarioContext:
        'A key dependency slipped and leadership needs the headline fast.',
    promptText:
        'Deliver a bottom-line-up-front update with the problem, impact, and ask.',
    targetDurationSec: 40,
    targetWordRangeMin: 55,
    targetWordRangeMax: 85,
    pillarWeights: {
      Pillar.clarity: 0.4,
      Pillar.structure: 0.4,
      Pillar.brevity: 0.2,
    },
    behaviorTargets: {'bluf_usage_rate': 0.85},
  ),
  PromptTemplate(
    id: 'plan-8',
    slug: 'plan-8',
    title: 'Answer under ambiguity',
    category: PromptCategory.directAnswerDiscipline,
    difficultyTier: 3,
    scenarioContext:
        'The data is incomplete but leadership still wants a recommendation.',
    promptText:
        'Give your recommendation, note the uncertainty, and propose the safest next move.',
    targetDurationSec: 50,
    targetWordRangeMin: 60,
    targetWordRangeMax: 95,
    pillarWeights: {
      Pillar.clarity: 0.45,
      Pillar.structure: 0.25,
      Pillar.pressureResponse: 0.3,
    },
    behaviorTargets: {'direct_answer_rate': 0.85},
  ),
];
