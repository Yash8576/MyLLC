import { writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const repoRoot = path.resolve(__dirname, '..')
const outputPath = path.join(
  repoRoot,
  'src',
  'app',
  'nexacore',
  'nexalgo',
  'generatedSeed.json',
)

const COMPANY_MAP = {
  1: ['Amazon', 'Google', 'Meta'],
  2: ['Amazon', 'Microsoft', 'Meta'],
  3: ['Amazon', 'Google', 'Bloomberg'],
  4: ['Google', 'Meta', 'Apple'],
  5: ['Amazon', 'Microsoft', 'Meta'],
  6: ['Amazon', 'Adobe'],
  7: ['Amazon', 'Microsoft'],
  8: ['Amazon', 'Bloomberg'],
  9: ['Google', 'Microsoft'],
  10: ['Google', 'Meta'],
  11: ['Amazon', 'Meta', 'Google'],
  12: ['Amazon', 'Microsoft'],
  13: ['Amazon', 'Meta'],
  14: ['Amazon', 'Google'],
  15: ['Amazon', 'Meta', 'Apple'],
  16: ['Amazon', 'Google'],
  17: ['Amazon', 'Google'],
  18: ['Amazon', 'Google'],
  19: ['Amazon', 'Meta'],
  20: ['Amazon', 'Google', 'Meta'],
  21: ['Amazon', 'Microsoft'],
  22: ['Amazon', 'Google'],
  23: ['Google', 'Amazon'],
  24: ['Amazon', 'Meta'],
  26: ['Amazon', 'Meta'],
  27: ['Amazon', 'Google'],
  28: ['Amazon', 'Google'],
  33: ['Amazon', 'Microsoft'],
  34: ['Amazon', 'Meta'],
  36: ['Amazon', 'Bloomberg'],
  39: ['Amazon', 'Google'],
  42: ['Amazon', 'Meta', 'Google'],
  46: ['Amazon', 'Meta'],
  48: ['Amazon', 'Meta'],
  49: ['Amazon', 'Google'],
  53: ['Amazon', 'LinkedIn', 'Meta'],
  54: ['Amazon', 'Meta'],
  55: ['Amazon', 'Meta'],
  56: ['Amazon', 'Meta'],
  57: ['Amazon', 'Meta'],
  62: ['Amazon', 'Google'],
  70: ['Amazon', 'Google'],
  72: ['Amazon', 'Meta'],
  73: ['Amazon', 'Meta'],
  76: ['Amazon', 'Meta'],
  78: ['Amazon', 'Meta'],
  79: ['Amazon', 'Meta'],
  88: ['Amazon', 'Meta'],
  98: ['Amazon', 'Meta'],
  100: ['Amazon', 'Meta'],
}

function decodeHtml(text) {
  return text
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
}

function stripMarkup(text) {
  return decodeHtml(text)
    .replace(/<iframe[\s\S]*?<\/iframe>/gi, '')
    .replace(/<pre>/gi, '\n')
    .replace(/<\/pre>/gi, '\n')
    .replace(/<li>/gi, '- ')
    .replace(/<\/li>/gi, '\n')
    .replace(/<\/?(p|div|ul|ol|strong|em|code|sup|font|span)[^>]*>/gi, '')
    .replace(/\[TOC\]/g, '')
    .replace(/\$\$/g, '')
    .replace(/\r/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

function extractSection(text, heading) {
  const lowerText = text.toLowerCase()
  const marker = `${heading}\n\n`.toLowerCase()
  const start = lowerText.indexOf(marker)
  if (start === -1) return ''

  const bodyStart = start + marker.length
  const terminators = ['\n\n## ', '\n\n### ', '\n\n---', '\n\n**']
    .map((value) => lowerText.indexOf(value, bodyStart))
    .filter((index) => index !== -1)
  const end = terminators.length > 0 ? Math.min(...terminators) : text.length
  return text.slice(bodyStart, end).trim()
}

function extractBoldSection(text, heading) {
  const lowerText = text.toLowerCase()
  const marker = `**${heading}**\n\n`.toLowerCase()
  const start = lowerText.indexOf(marker)
  if (start === -1) return ''

  const bodyStart = start + marker.length
  const terminators = ['\n\n**', '\n\n### ', '\n\n---']
    .map((value) => lowerText.indexOf(value, bodyStart))
    .filter((index) => index !== -1)
  const end = terminators.length > 0 ? Math.min(...terminators) : text.length
  return text.slice(bodyStart, end).trim()
}

function toLanguageMap(codeSnippets) {
  const wanted = {
    python3: 'python',
    java: 'java',
    cpp: 'cpp',
  }

  return codeSnippets.reduce((acc, snippet) => {
    const key = wanted[snippet.langSlug]
    if (key) {
      acc[key] = decodeHtml(snippet.code).trimEnd()
    }
    return acc
  }, {})
}

async function fetchProblemDetail(titleSlug) {
  const body = {
    query: `
      query questionData($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
          questionFrontendId
          title
          titleSlug
          difficulty
          topicTags {
            name
            slug
          }
          hints
          content
          solution {
            content
          }
          codeSnippets {
            lang
            langSlug
            code
          }
        }
      }
    `,
    variables: { titleSlug },
  }

  const response = await fetch('https://leetcode.com/graphql', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  })

  if (!response.ok) {
    throw new Error(`Failed to fetch ${titleSlug}: ${response.status}`)
  }

  const json = await response.json()
  return json.data.question
}

async function main() {
  const catalogResponse = await fetch('https://leetcode.com/api/problems/all/')
  if (!catalogResponse.ok) {
    throw new Error(`Failed to fetch problem catalog: ${catalogResponse.status}`)
  }

  const catalog = await catalogResponse.json()
  const firstHundred = catalog.stat_status_pairs
    .filter(
      (entry) =>
        /^\d+$/.test(String(entry.stat.frontend_question_id)) && !entry.paid_only,
    )
    .map((entry) => ({
      id: Number(entry.stat.frontend_question_id),
      slug: entry.stat.question__title_slug,
    }))
    .sort((a, b) => a.id - b.id)
    .slice(0, 100)

  const seed = []

  for (const item of firstHundred) {
    const detail = await fetchProblemDetail(item.slug)
    const cleanedSolution = stripMarkup(detail.solution?.content ?? '')
    const cleanedProblem = stripMarkup(detail.content ?? '')
    const intuition =
      extractBoldSection(cleanedSolution, 'Intuition') ||
      extractSection(cleanedSolution, '### Approach 1: Brute Force') ||
      ''
    const walkthrough =
      extractBoldSection(cleanedSolution, 'Algorithm') ||
      extractSection(cleanedSolution, '### Approach 2: Two-pass Hash Table') ||
      extractSection(cleanedSolution, '### Approach 1: Brute Force') ||
      ''
    const complexity =
      extractBoldSection(cleanedSolution, 'Complexity Analysis') || ''

    seed.push({
      id: Number(detail.questionFrontendId),
      title: detail.title,
      slug: detail.titleSlug,
      difficulty: detail.difficulty,
      topics: detail.topicTags.map((tag) => tag.name),
      companies: COMPANY_MAP[Number(detail.questionFrontendId)] ?? [],
      link: `https://leetcode.com/problems/${detail.titleSlug}/description/`,
      problemStatement: cleanedProblem,
      hints: detail.hints.map((hint) => stripMarkup(hint)),
      whatToUse: detail.topicTags.map((tag) => tag.name),
      intuition,
      walkthrough,
      complexity,
      starterCodeByLanguage: toLanguageMap(detail.codeSnippets),
      officialSolution: cleanedSolution,
    })
  }

  await writeFile(outputPath, `${JSON.stringify(seed, null, 2)}\n`)
  console.log(`Wrote ${seed.length} problems to ${outputPath}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
