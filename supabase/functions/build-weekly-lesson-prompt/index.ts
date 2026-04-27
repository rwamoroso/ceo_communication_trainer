import { corsHeaders } from '../_shared/http.ts';
import { weeklyLessonPacketPrompt } from '../_shared/prompts.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await request.json();
    const prompt = weeklyLessonPacketPrompt(body);

    return Response.json(
      {
        status: 'ok',
        prompt,
        contract: {
          week_number: 'int',
          weekly_objective: 'string',
          development_summary: 'string',
          drills: [
            {
              plan_item_id: 'string',
              lesson_title: 'string',
              lesson_body: 'string',
              good_example: 'string',
              example_analysis: 'string',
              user_development_focus: 'string',
              pre_drill_checklist: ['string'],
            },
          ],
        },
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
