export const defaultOpenAiModel = 'gpt-5.4-mini-2026-03-17';

type GenerateStructuredJsonOptions = {
  prompt: string;
  schemaName: string;
  schema: Record<string, unknown>;
  model?: string;
  maxOutputTokens?: number;
};

export async function generateStructuredJson<T>({
  prompt,
  schemaName,
  schema,
  model = defaultOpenAiModel,
  maxOutputTokens = 2200,
}: GenerateStructuredJsonOptions): Promise<T> {
  const apiKey = Deno.env.get('OPENAI_API_KEY');
  if (!apiKey) {
    throw new Error(
      'OPENAI_API_KEY is not configured for this Supabase project.',
    );
  }

  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    signal: AbortSignal.timeout(45_000),
    body: JSON.stringify({
      model,
      input: [
        {
          role: 'system',
          content: [{ type: 'input_text', text: prompt }],
        },
        {
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: 'Return only the JSON object that matches the requested schema.',
            },
          ],
        },
      ],
      text: {
        format: {
          type: 'json_schema',
          name: schemaName,
          strict: true,
          schema,
        },
      },
      max_output_tokens: maxOutputTokens,
    }),
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw new Error(
      `OpenAI request failed with status ${response.status}: ${errorMessageFromPayload(payload)}`,
    );
  }

  const refusal = extractRefusal(payload);
  if (refusal) {
    throw new Error(`OpenAI refusal: ${refusal}`);
  }

  const parsed = extractParsedOutput(payload);
  if (parsed !== undefined) {
    return parsed as T;
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    throw new Error('OpenAI response did not include structured output text.');
  }

  try {
    return JSON.parse(outputText) as T;
  } catch (error) {
    throw new Error(
      `OpenAI response JSON could not be parsed: ${error instanceof Error ? error.message : 'Unknown parse error.'}`,
    );
  }
}

function errorMessageFromPayload(payload: unknown): string {
  const record = asRecord(payload);
  const error = asRecord(record.error);
  return error.message?.toString() ?? 'Unknown OpenAI error.';
}

function extractRefusal(payload: unknown): string {
  const record = asRecord(payload);
  for (const item of asArray(record.output)) {
    const output = asRecord(item);
    for (const content of asArray(output.content)) {
      const chunk = asRecord(content);
      if (chunk.type === 'refusal' && chunk.refusal != null) {
        return chunk.refusal.toString();
      }
    }
  }
  return '';
}

function extractParsedOutput(payload: unknown): unknown {
  const record = asRecord(payload);
  if (record.output_parsed !== undefined) {
    return record.output_parsed;
  }

  for (const item of asArray(record.output)) {
    const output = asRecord(item);
    for (const content of asArray(output.content)) {
      const chunk = asRecord(content);
      if (chunk.parsed !== undefined) {
        return chunk.parsed;
      }
    }
  }

  return undefined;
}

function extractOutputText(payload: unknown): string {
  const record = asRecord(payload);
  if (typeof record.output_text === 'string') {
    return record.output_text;
  }

  for (const item of asArray(record.output)) {
    const output = asRecord(item);
    for (const content of asArray(output.content)) {
      const chunk = asRecord(content);
      if (
        (chunk.type === 'output_text' || chunk.type === 'text') &&
        typeof chunk.text === 'string'
      ) {
        return chunk.text;
      }
    }
  }

  return '';
}

function asRecord(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}
