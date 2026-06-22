import { corsHeaders } from '../_shared/http.ts';
import { generateStructuredJson } from '../_shared/openai.ts';
import { weeklyLessonPacketPrompt } from '../_shared/prompts.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = asRecord(await request.json(), 'Request body');
    const prompt = weeklyLessonPacketPrompt(body);
    const weekItems = extractWeekItems(body);

    try {
      const packet = await generateStructuredJson<Record<string, unknown>>({
        prompt,
        schemaName: 'weekly_lesson_packet',
        schema: buildPacketSchema(weekItems.length),
        maxOutputTokens: 2600,
      });

      return Response.json(
        {
          status: 'ok',
          prompt,
          packet: normalizePacket(packet),
          contract: packetContract(),
        },
        { headers: corsHeaders },
      );
    } catch (error) {
      return Response.json(
        {
          status: 'prompt_only',
          prompt,
          warning: error instanceof Error ? error.message : 'Unknown error',
          contract: packetContract(),
        },
        { headers: corsHeaders },
      );
    }
  } catch (error) {
    return Response.json(
      {
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 400, headers: corsHeaders },
    );
  }
});

function buildPacketSchema(drillCount: number) {
  return {
    type: 'object',
    additionalProperties: false,
    required: [
      'week_number',
      'weekly_objective',
      'development_summary',
      'previous_week_analysis',
      'previous_week_evaluations',
      'drills',
    ],
    properties: {
      week_number: { type: 'integer' },
      weekly_objective: { type: 'string' },
      development_summary: { type: 'string' },
      previous_week_analysis: { type: 'string' },
      previous_week_evaluations: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: ['session_id', 'ai_score', 'key_observations'],
          properties: {
            session_id: { type: 'string' },
            ai_score: { type: 'number' },
            key_observations: {
              type: 'array',
              items: { type: 'string' },
            },
          },
        },
      },
      drills: {
        type: 'array',
        minItems: drillCount,
        maxItems: drillCount,
        items: {
          type: 'object',
          additionalProperties: false,
          required: [
            'plan_item_id',
            'lesson_title',
            'lesson_body',
            'good_example',
            'example_analysis',
            'user_development_focus',
            'pre_drill_checklist',
            'drill_purpose',
            'success_signals',
            'ai_scenario_context',
            'ai_prompt_text',
          ],
          properties: {
            plan_item_id: { type: 'string' },
            lesson_title: { type: 'string' },
            lesson_body: { type: 'string' },
            good_example: { type: 'string' },
            example_analysis: { type: 'string' },
            user_development_focus: { type: 'string' },
            pre_drill_checklist: {
              type: 'array',
              minItems: 1,
              items: { type: 'string' },
            },
            drill_purpose: { type: 'string' },
            success_signals: {
              type: 'array',
              minItems: 3,
              maxItems: 3,
              items: { type: 'string' },
            },
            ai_scenario_context: { type: 'string' },
            ai_prompt_text: { type: 'string' },
          },
        },
      },
    },
  } as const;
}

function normalizePacket(payload: Record<string, unknown>) {
  const drills = asArray(payload.drills, 'drills').map((entry, index) => {
    const drill = asRecord(entry, `drills[${index}]`);
    return {
      plan_item_id: asNonEmptyString(
        drill.plan_item_id,
        `drills[${index}].plan_item_id`,
      ),
      lesson_title: asNonEmptyString(
        drill.lesson_title,
        `drills[${index}].lesson_title`,
      ),
      lesson_body: asNonEmptyString(
        drill.lesson_body,
        `drills[${index}].lesson_body`,
      ),
      good_example: asNonEmptyString(
        drill.good_example,
        `drills[${index}].good_example`,
      ),
      example_analysis: asNonEmptyString(
        drill.example_analysis,
        `drills[${index}].example_analysis`,
      ),
      user_development_focus: asNonEmptyString(
        drill.user_development_focus,
        `drills[${index}].user_development_focus`,
      ),
      pre_drill_checklist: asNonEmptyStringList(
        drill.pre_drill_checklist,
        `drills[${index}].pre_drill_checklist`,
      ),
      drill_purpose: asNonEmptyString(
        drill.drill_purpose,
        `drills[${index}].drill_purpose`,
      ),
      success_signals: asNonEmptyStringList(
        drill.success_signals,
        `drills[${index}].success_signals`,
        { exactItems: 3 },
      ),
      ai_scenario_context: asNonEmptyString(
        drill.ai_scenario_context,
        `drills[${index}].ai_scenario_context`,
      ),
      ai_prompt_text: asNonEmptyString(
        drill.ai_prompt_text,
        `drills[${index}].ai_prompt_text`,
      ),
    };
  });

  const evaluations = asArray(
    payload.previous_week_evaluations,
    'previous_week_evaluations',
  ).map((entry, index) => {
    const evaluation = asRecord(
      entry,
      `previous_week_evaluations[${index}]`,
    );
    return {
      session_id: asNonEmptyString(
        evaluation.session_id,
        `previous_week_evaluations[${index}].session_id`,
      ),
      ai_score: asNumber(
        evaluation.ai_score,
        `previous_week_evaluations[${index}].ai_score`,
      ),
      key_observations: asNonEmptyStringList(
        evaluation.key_observations,
        `previous_week_evaluations[${index}].key_observations`,
      ),
    };
  });

  return {
    week_number: asInteger(payload.week_number, 'week_number'),
    weekly_objective: asNonEmptyString(
      payload.weekly_objective,
      'weekly_objective',
    ),
    development_summary: asNonEmptyString(
      payload.development_summary,
      'development_summary',
    ),
    previous_week_analysis:
      payload.previous_week_analysis?.toString().trim() ?? '',
    previous_week_evaluations: evaluations,
    drills,
  };
}

function extractWeekItems(body: Record<string, unknown>): Record<string, unknown>[] {
  const plan = asRecord(body.plan, 'plan');
  return asArray(plan.week_items, 'plan.week_items').map((entry, index) =>
    asRecord(entry, `plan.week_items[${index}]`),
  );
}

function packetContract() {
  return {
    week_number: 'int',
    weekly_objective: 'string',
    development_summary: 'string',
    previous_week_analysis: 'string',
    previous_week_evaluations: [
      {
        session_id: 'string',
        ai_score: 'number',
        key_observations: ['string'],
      },
    ],
    drills: [
      {
        plan_item_id: 'string',
        lesson_title: 'string',
        lesson_body: 'string',
        good_example: 'string',
        example_analysis: 'string',
        user_development_focus: 'string',
        pre_drill_checklist: ['string'],
        drill_purpose: 'string',
        success_signals: ['string', 'string', 'string'],
        ai_scenario_context: 'string',
        ai_prompt_text: 'string',
      },
    ],
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

function asArray(value: unknown, label: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be an array.`);
  }
  return value;
}

function asNumber(value: unknown, label: string): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  throw new Error(`${label} must be a finite number.`);
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
  options: { exactItems?: number } = {},
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
  if (
    options.exactItems != null &&
    normalized.length !== options.exactItems
  ) {
    throw new Error(
      `${label} must contain exactly ${options.exactItems} items.`,
    );
  }
  return normalized;
}
