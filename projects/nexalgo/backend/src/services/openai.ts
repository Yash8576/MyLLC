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
  intuition: `Start from the problem statement for ${payload.title} and reduce it to a repeatable pattern driven by the constraints and target output.`,
  walkthrough:
    '1. Parse the input shape.\n2. Choose the core data structure or traversal strategy.\n3. Build the solution incrementally and verify edge cases.\n4. Return the result in the required format.',
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
    'hints must be an array of short strings.',
    'Solutions must be complete and directly solve the problem statement.',
    `Platform: ${payload.platform}`,
    `URL: ${payload.normalizedUrl}`,
    `Title: ${payload.title}`,
    `Difficulty: ${payload.difficulty ?? 'Unknown'}`,
    `Topics: ${(payload.topics ?? []).join(', ')}`,
    `Companies: ${(payload.companies ?? []).join(', ')}`,
    `Problem statement:\n${payload.problemStatement}`,
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
