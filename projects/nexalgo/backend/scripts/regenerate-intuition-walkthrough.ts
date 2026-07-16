// One-off: regenerate ONLY intuition + walkthrough for every published
// problem, in the new bullet-point format. Leaves hints, solutions,
// complexityAnalysis, and everything else untouched. Existing solution code
// is passed to the model as context so the walkthrough describes the code
// that's actually stored, not a different approach.
//
// Run with: npx tsx scripts/regenerate-intuition-walkthrough.ts [--dry-run]

import { PrismaClient, ProblemStatus } from '@prisma/client'
import { regenerateIntuitionWalkthrough } from '../src/services/openai.js'

const prisma = new PrismaClient()

async function main() {
  const dryRun = process.argv.includes('--dry-run')

  const problems = await prisma.problem.findMany({
    where: { status: ProblemStatus.published },
    orderBy: { problemNumber: 'asc' },
  })

  console.log(`Found ${problems.length} published problems.`)
  if (dryRun) {
    console.log('Dry run - will call the model but not write to the DB.')
  }

  let updated = 0
  let skipped = 0

  for (const [index, problem] of problems.entries()) {
    const solutions = (problem.solutions as Record<string, string>) ?? {}
    const result = await regenerateIntuitionWalkthrough({
      title: problem.title,
      difficulty: problem.difficulty,
      problemStatement: problem.problemStatement,
      topics: Array.isArray(problem.topics) ? (problem.topics as string[]) : [],
      companies: Array.isArray(problem.companies) ? (problem.companies as string[]) : [],
      pythonSolution: solutions.python,
      javaSolution: solutions.java,
      cppSolution: solutions.cpp,
    })

    if (!result) {
      console.log(`  [${index + 1}/${problems.length}] SKIP (no result): ${problem.title}`)
      skipped++
      continue
    }

    if (!dryRun) {
      await prisma.problem.update({
        where: { id: problem.id },
        data: {
          intuition: result.intuition,
          walkthrough: result.walkthrough,
        },
      })
    }

    console.log(`  [${index + 1}/${problems.length}] OK: ${problem.title}`)
    updated++

    // Gentle pacing to stay comfortably under rate limits.
    await new Promise((resolve) => setTimeout(resolve, 500))
  }

  console.log('Done.')
  console.log(`  Updated: ${updated}`)
  console.log(`  Skipped: ${skipped}`)
}

main()
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
