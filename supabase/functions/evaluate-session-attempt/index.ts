import { corsHeaders } from '../_shared/http.ts';
import {
  defaultOpenAiModel,
  generateStructuredJson,
} from '../_shared/openai.ts';
import { sessionCoachingPrompt } from '../_shared/prompts.ts';

const scoringVersion = `ai-v1:${defaultOpenAiModel}`;

const evaluationSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'overall_score',
    'pillar_scores',
    'behavior_metrics',
    'biggest_issue',
    'secondary_issue',
    'what_worked',
    'top_coaching_points',
    'improved_example_answer',
    'next_attempt_target',
  ],
  properties: {
    overall_score: { type: 'number' },
    pillar_scores: {
      type: 'object',
      additionalProperties: false,
      required: [
        'clarity',
        'structure',
        'brevity',
        'presence',
        'strategic_framing',
        'pressure_response',
      ],
      properties: {
        clarity: { type: 'number' },
        structure: { type: 'number' },
        brevity: { type: 'number' },
        presence: { type: 'number' },
        strategic_framing: { type: 'number' },
        pressure_response: { type: 'number' },
      },
    },
    behavior_metrics: {
      type: 'object',
      additionalProperties: false,
      required: [
        'direct_answer_rate',
        'bluf_usage_rate',
        'clean_three_point_structure_rate',
        'average_response_length_words',
        'filler_words_per_minute',
        'words_per_minute',
        'retry_count',
        'coaching_adoption_rate',
        'consistency',
        'missed_sessions',
        'difficulty_tolerance',
      ],
      properties: {
        direct_answer_rate: { type: 'number' },
        bluf_usage_rate: { type: 'number' },
        clean_three_point_structure_rate: { type: 'number' },
        average_response_length_words: { type: 'number' },
        filler_words_per_minute: {
          anyOf: [{ type: 'number' }, { type: 'null' }],
        },
        words_per_minute: {
          anyOf: [{ type: 'number' }, { type: 'null' }],
        },
        retry_count: { type: 'integer' },
        coaching_adoption_rate: { type: 'number' },
        consistency: { type: 'number' },
        missed_sessions: { type: 'integer' },
        difficulty_tolerance: { type: 'number' },
      },
    },
    biggest_issue: { type: 'string' },
    secondary_issue: { type: 'string' },
    what_worked: { type: 'string' },
    top_coaching_points: {
      type: 'array',
      minItems: 1,
      maxItems: 3,
      items: { type: 'string' },
    },
    improved_example_answer: { type: 'string' },
    next_attempt_target: { type: 'string' },
  },
} as const;

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = asRecord(await request.json(), 'Request body');
    const prompt = sessionCoachingPrompt(body);
    const generated = await generateStructuredJson<Record<string, unknown>>({
      prompt,
      schemaName: 'session_attempt_evaluation',
      schema: evaluationSchema,
      maxOutputTokens: 1800,
    });

    return Response.json(normalizeEvaluation(generated), {
      headers: corsHeaders,
    });
  } catch (error) {
    return Response.json(
      {
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 400, headers: corsHeaders },
    );
  }
});

function normalizeEvaluation(payload: Record<string, unknown>) {
  const pillarScores = asRecord(payload.pillar_scores, 'pillar_scores');
  const behaviorMetrics = asRecord(
    payload.behavior_metrics,
    'behavior_metrics',
  );

  return {
    overall_score: asNumber(payload.overall_score, 'overall_score'),
    pillar_scores: {
      clarity: asNumber(pillarScores.clarity, 'pillar_scores.clarity'),
      structure: asNumber(pillarScores.structure, 'pillar_scores.structure'),
      brevity: asNumber(pillarScores.brevity, 'pillar_scores.brevity'),
      presence: asNumber(pillarScores.presence, 'pillar_scores.presence'),
      strategic_framing: asNumber(
        pillarScores.strategic_framing,
        'pillar_scores.strategic_framing',
      ),
      pressure_response: asNumber(
        pillarScores.pressure_response,
        'pillar_scores.pressure_response',
      ),
    },
    behavior_metrics: {
      direct_answer_rate: asNumber(
        behaviorMetrics.direct_answer_rate,
        'behavior_metrics.direct_answer_rate',
      ),
      bluf_usage_rate: asNumber(
        behaviorMetrics.bluf_usage_rate,
        'behavior_metrics.bluf_usage_rate',
      ),
      clean_three_point_structure_rate: asNumber(
        behaviorMetrics.clean_three_point_structure_rate,
        'behavior_metrics.clean_three_point_structure_rate',
      ),
      average_response_length_words: asNumber(
        behaviorMetrics.average_response_length_words,
        'behavior_metrics.average_response_length_words',
      ),
      filler_words_per_minute: asNullableNumber(
        behaviorMetrics.filler_words_per_minute,
        'behavior_metrics.filler_words_per_minute',
      ),
      words_per_minute: asNullableNumber(
        behaviorMetrics.words_per_minute,
        'behavior_metrics.words_per_minute',
      ),
      retry_count: asInteger(
        behaviorMetrics.retry_count,
        'behavior_metrics.retry_count',
      ),
      coaching_adoption_rate: asNumber(
        behaviorMetrics.coaching_adoption_rate,
        'behavior_metrics.coaching_adoption_rate',
      ),
      consistency: asNumber(
        behaviorMetrics.consistency,
        'behavior_metrics.consistency',
      ),
      missed_sessions: asInteger(
        behaviorMetrics.missed_sessions,
        'behavior_metrics.missed_sessions',
      ),
      difficulty_tolerance: asNumber(
        behaviorMetrics.difficulty_tolerance,
        'behavior_metrics.difficulty_tolerance',
      ),
    },
    biggest_issue: asNonEmptyString(payload.biggest_issue, 'biggest_issue'),
    secondary_issue: asNonEmptyString(
      payload.secondary_issue,
      'secondary_issue',
    ),
    what_worked: asNonEmptyString(payload.what_worked, 'what_worked'),
    top_coaching_points: asNonEmptyStringList(
      payload.top_coaching_points,
      'top_coaching_points',
      { maxItems: 3 },
    ),
    improved_example_answer: asNonEmptyString(
      payload.improved_example_answer,
      'improved_example_answer',
    ),
    next_attempt_target: asNonEmptyString(
      payload.next_attempt_target,
      'next_attempt_target',
    ),
    scoring_version: scoringVersion,
    feedback_version: scoringVersion,
  };
}

function asRecord(
  value: unknown,
  label: string,
): Record<string, unknown> {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function asNumber(value: unknown, label: string): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  throw new Error(`${label} must be a finite number.`);
}

function asNullableNumber(value: unknown, label: string): number | null {
  if (value == null) {
    return null;
  }
  return asNumber(value, label);
}

function asInteger(value: unknown, label: string): number {
  const parsed = asNumber(value, label);
  if (!Number.isInteger(parsed)) {
    throw new Error(`${label} must be an integer.`);
  }
  return parsed;
}

function asNonEmptyString(value: unknown, label: string): string {
  const normalized = value?.toString().trim() ?? '';
  if (!normalized) {
    throw new Error(`${label} must be a non-empty string.`);
  }
  return normalized;
}

function asNonEmptyStringList(
  value: unknown,
  label: string,
  options: { maxItems?: number } = {},
): string[] {
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be an array of strings.`);
  }

  const normalized = value
    .map((entry) => entry?.toString().trim() ?? '')
    .filter((entry) => entry.length > 0);
  if (normalized.length === 0) {
    throw new Error(`${label} must contain at least one item.`);
  }
  if (options.maxItems != null && normalized.length > options.maxItems) {
    throw new Error(`${label} must contain at most ${options.maxItems} items.`);
  }
  return normalized;
}
