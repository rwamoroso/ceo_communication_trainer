export function baselinePlanPrompt(input: Record<string, unknown>) {
  return `
You are generating a 10-week executive communication training plan.

Rules:
- Return JSON only.
- Return exactly 10 weeks.
- Use only approved prompt IDs from the provided inventory.
- Keep 5 drill days per week.
- Do not emphasize strategic framing if clarity or structure are weak.
- Prioritize BLUF, direct answer, and structure first.

Inputs:
${JSON.stringify(input, null, 2)}

Output shape:
{
  "assigned_level": "Structured",
  "plan_summary": "Focus on answer-first structure before strategic framing.",
  "weeks": [
    {
      "week_number": 1,
      "primary_focus": ["clarity", "structure"],
      "secondary_focus": ["brevity"],
      "difficulty_tier": 2,
      "items": [
        {
          "day": 1,
          "drill_type": "bluf_answer",
          "prompt_pool": ["prompt-id"],
          "target_metrics": { "direct_answer_rate": 0.8 }
        }
      ]
    }
  ]
}
`;
}

export function weeklyRecalibrationPrompt(input: Record<string, unknown>) {
  return `
You are recalibrating an executive communication training plan.

Rules:
- Return JSON only.
- Respect deterministic rules already supplied.
- Preserve day counts and week counts.
- Do not remove required remediation drills.
- Increase difficulty by at most one tier.

Inputs:
${JSON.stringify(input, null, 2)}

Output shape:
{
  "classification": "Plateau",
  "summary": "Structure improved slowly; novelty reduced to reinforce repeatable form.",
  "rule_hits": ["low_structure", "plateau"],
  "changes": [
    {
      "week_number": 4,
      "replace_drill_type": "strategic_reframe",
      "with_drill_type": "three_point_update",
      "difficulty_tier": 2
    }
  ]
}
`;
}

export function sessionCoachingPrompt(input: Record<string, unknown>) {
  return `
You are scoring one executive communication drill attempt.

Rules:
- Return JSON only.
- Score the response against the drill purpose, success signals, prompt, and weekly lesson context.
- Be honest and specific. Do not inflate scores to be encouraging.
- Keep scores internally consistent with the written feedback.
- Give at most 3 coaching points.
- Keep the improved example concise enough to fit the target duration.
- Use prior attempt feedback and same-topic history only to personalize coaching, not to overwrite what happened in this attempt.
- For typed responses, filler_words_per_minute and words_per_minute can be null.

Inputs:
${JSON.stringify(input, null, 2)}

Output shape:
{
  "overall_score": 64,
  "pillar_scores": {
    "clarity": 68,
    "structure": 60,
    "brevity": 55,
    "presence": 62,
    "strategic_framing": 58,
    "pressure_response": 54
  },
  "behavior_metrics": {
    "direct_answer_rate": 0.4,
    "bluf_usage_rate": 0.2,
    "clean_three_point_structure_rate": 0.35,
    "average_response_length_words": 96,
    "filler_words_per_minute": 8.0,
    "words_per_minute": 152,
    "retry_count": 1,
    "coaching_adoption_rate": 0.45,
    "consistency": 0.58,
    "missed_sessions": 0,
    "difficulty_tolerance": 0.52
  },
  "biggest_issue": "You delayed the answer.",
  "secondary_issue": "Your middle section wandered.",
  "what_worked": "Your recommendation became clearer near the end.",
  "top_coaching_points": [
    "Lead with the answer in one sentence.",
    "Use exactly three points.",
    "Cut the setup in half."
  ],
  "improved_example_answer": "My recommendation is X for three reasons...",
  "next_attempt_target": "State the recommendation in the first sentence and keep the whole response under 45 seconds."
}
`;
}

export function weeklyLessonPacketPrompt(input: Record<string, unknown>) {
  const weekNumber =
    typeof input.plan === 'object' &&
    input.plan !== null &&
    'week_number' in input.plan
      ? (input.plan as { week_number?: number }).week_number ?? 'unknown'
      : 'unknown';

  return `
You are creating an executive communication lesson packet for one training week.

Goal:
- Prepare the user for this week's scheduled drills.
- Teach the topic before each drill starts.
- Show what strong execution looks like.
- Analyze the user's specific development areas on each topic using prior responses and coaching history.
- Generate a short drill purpose and exactly 3 success signals for each drill so the user knows what the exercise is training.
- Treat ai_scenario_context and ai_prompt_text as the exact scenario and question the user will see for next week's drills.

Rules:
- Return JSON only.
- Do not wrap the JSON in markdown.
- Keep every drill aligned to the existing scheduled plan item.
- Use the prior week's answers and coaching to personalize the development focus.
- Use recent same-topic history to call out recurring strengths and weaknesses.
- Keep lesson content concise, practical, and coaching-oriented.
- Every current-week plan item must appear exactly once in the drills array.
- Write ai_scenario_context and ai_prompt_text for every drill.
- success_signals must contain exactly 3 concrete, observable signals of a strong answer.

Inputs:
${JSON.stringify(input, null, 2)}

Return this exact JSON shape:
{
  "week_number": ${JSON.stringify(weekNumber)},
  "weekly_objective": "One clear sentence describing the week's coaching goal.",
  "development_summary": "A concise analysis of the user's development needs entering this week.",
  "drills": [
    {
      "plan_item_id": "exact-plan-item-id",
      "lesson_title": "Short title",
      "lesson_body": "Teach the skill for this drill.",
      "good_example": "A strong example response for this drill.",
      "example_analysis": "Why the example works.",
      "user_development_focus": "How this user should improve on this topic based on prior responses.",
      "drill_purpose": "One sentence explaining what this drill is training.",
      "success_signals": [
        "Concrete signal of a strong answer",
        "Concrete signal of a strong answer",
        "Concrete signal of a strong answer"
      ],
      "pre_drill_checklist": [
        "Short checklist item",
        "Short checklist item"
      ],
      "ai_scenario_context": "A realistic scenario paragraph tailored to the user's role and industry.",
      "ai_prompt_text": "The specific question or prompt the user will respond to in this drill."
    }
  ]
}
`;
}
