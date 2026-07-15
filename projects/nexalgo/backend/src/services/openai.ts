import { env } from '../config/env.js'

type ScrapedPayload = {
  title: string
  difficulty?: string
  problemStatement: string
  topics?: string[]
  companies?: string[]
  platform: string
  normalizedUrl: string
}

export type GeneratedSections = {
  hints: string[]
  intuition: string
  walkthrough: string
  complexityAnalysis: string
  pythonSolution: string
  javaSolution: string
  cppSolution: string
}

const fallbackGeneration = (payload: ScrapedPayload): GeneratedSections => ({
  hints: [
    `Identify the data structure that best fits ${payload.title}.`,
    'Write the brute-force solution first and then remove repeated work.',
    'Check edge cases from the statement and constraints before coding.',
  ],
  intuition: [
    `Start from the problem statement for ${payload.title} and look for the repeatable pattern behind it.`,
    'Consider what a brute-force approach would do, and why it does redundant work.',
    'Identify the data structure or technique that removes that redundant work.',
  ].join('\n'),
  walkthrough:
    'Brute force:\nParse the input shape.\nTry the direct/naive approach and note where it repeats work.\n\nOptimal:\nChoose the core data structure or traversal strategy.\nBuild the solution incrementally and verify edge cases.\nReturn the result in the required format.',
  complexityAnalysis:
    'Document both time and space complexity using the dominant loop, recursion depth, and extra memory allocations.',
  pythonSolution: '# Provide the Python implementation here.\nclass Solution:\n    pass',
  javaSolution: '// Provide the Java implementation here.\nclass Solution {\n}',
  cppSolution: '// Provide the C++ implementation here.\nclass Solution {\n};',
})

function extractOutputText(response: any) {
  if (typeof response.output_text === 'string' && response.output_text.trim()) {
    return response.output_text
  }

  const chunks = response.output
    ?.flatMap((item: any) => item.content ?? [])
    ?.filter((item: any) => item.type === 'output_text')
    ?.map((item: any) => item.text)

  return Array.isArray(chunks) ? chunks.join('') : ''
}

export async function generateProblemContent(
  payload: ScrapedPayload,
): Promise<GeneratedSections> {
  if (!env.OPENAI_API_KEY) {
    return fallbackGeneration(payload)
  }

  const prompt = [
    'Generate editorial content for a coding interview problem as strict JSON.',
    'Return keys: hints, intuition, walkthrough, complexityAnalysis, pythonSolution, javaSolution, cppSolution.',
    '',
    'FORMAT RULES - read carefully, these are rendered as bullet lists in the UI, not prose:',
    '- hints: an array of short strings. Each one a single clarifying question or hint a candidate might ask/need before coding.',
    '- intuition: PLAIN TEXT with ONE POINT PER LINE (separate points with a single newline). Do not write a flowing paragraph and do not number the lines or prefix them with "-" or "*". 3-6 short lines that build up the key realization, the same way a candidate would think out loud: what pattern do you notice, what would a naive approach do, why is it slow, what is the key insight that leads to the efficient approach.',
    '- walkthrough: for EACH approach that actually exists for this problem, write a line with just the approach label followed by a colon on its own (use exactly "Brute force:" and/or "Optimal:" - omit "Brute force:" entirely if there is no meaningfully different naive approach), then on the following lines write 3-6 short bullet points (one step per line, no numbering, no "-"/"*" prefix) walking through that approach step by step. Separate the Brute force block and the Optimal block with a single blank line. Every line under a label must be a short, single-idea bullet - never a multi-sentence paragraph.',
    '- complexityAnalysis: for each approach present, a line "Brute force: Time O(...); Space O(...)" and/or "Optimal: Time O(...); Space O(...)", separated by a blank line if both are present.',
    'Solutions must be complete and directly solve the problem statement.',
    `Platform: ${payload.platform}`,
    `URL: ${payload.normalizedUrl}`,
    `Title: ${payload.title}`,
    `Difficulty: ${payload.difficulty ?? 'Unknown'}`,
    `Topics: ${(payload.topics ?? []).join(', ')}`,
    `Companies: ${(payload.companies ?? []).join(', ')}`,
    `Problem statement (context only - do not repeat it back, it is not shown to the user):\n${payload.problemStatement}`,
  ].join('\n')

  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: env.OPENAI_MODEL,
      input: prompt,
      text: {
        format: {
          type: 'json_schema',
          name: 'nexalgo_generation',
          schema: {
            type: 'object',
            additionalProperties: false,
            properties: {
              hints: {
                type: 'array',
                items: { type: 'string' },
              },
              intuition: { type: 'string' },
              walkthrough: { type: 'string' },
              complexityAnalysis: { type: 'string' },
              pythonSolution: { type: 'string' },
              javaSolution: { type: 'string' },
              cppSolution: { type: 'string' },
            },
            required: [
              'hints',
              'intuition',
              'walkthrough',
              'complexityAnalysis',
              'pythonSolution',
              'javaSolution',
              'cppSolution',
            ],
          },
        },
      },
    }),
  })

  if (!response.ok) {
    return fallbackGeneration(payload)
  }

  const json = await response.json()
  const outputText = extractOutputText(json)
  if (!outputText) {
    return fallbackGeneration(payload)
  }

  try {
    const parsed = JSON.parse(outputText) as GeneratedSections
    return parsed
  } catch {
    return fallbackGeneration(payload)
  }
}
