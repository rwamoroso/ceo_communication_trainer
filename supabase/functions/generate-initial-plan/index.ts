import { corsHeaders } from '../_shared/http.ts';
import { baselinePlanPrompt } from '../_shared/prompts.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await request.json();
    const prompt = baselinePlanPrompt(body);

    return Response.json(
      {
        status: 'stubbed',
        message:
          'Function contract is ready. Replace this stub with model generation, validation, and publish_training_plan_version wiring.',
        system_prompt: prompt,
      },
      { headers: corsHeaders },
    );
  } catch (error) {
    return Response.json(
      {
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 400, headers: corsHeaders },
    );
  }
});
