import { corsHeaders } from '../_shared/http.ts';
import { weeklyRecalibrationPrompt } from '../_shared/prompts.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await request.json();
    const prompt = weeklyRecalibrationPrompt(body);

    return Response.json(
      {
        status: 'stubbed',
        message:
          'Recalibration scaffold is ready. Next step is deterministic-rule enforcement, model generation, and plan patch persistence.',
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
