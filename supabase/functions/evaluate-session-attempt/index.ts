import { corsHeaders } from '../_shared/http.ts';
import { sessionCoachingPrompt } from '../_shared/prompts.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await request.json();
    const prompt = sessionCoachingPrompt(body);

    return Response.json(
      {
        status: 'stubbed',
        message:
          'Edge function scaffold is in place. Next implementation step is model invocation plus JSON-schema validation and persistence.',
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
