// Applies hand-written intuition + walkthrough content (keyed by slug) to
// the matching published problems. Only touches those two fields - leaves
// solutions, hints, complexityAnalysis, and everything else untouched.
//
// Run with: npx tsx scripts/apply-intuition-walkthrough.ts <path-to-content.json> [--dry-run]

import { readFileSync } from 'node:fs'
import { PrismaClient, ProblemStatus } from '@prisma/client'

const prisma = new PrismaClient()

type ContentEntry = { intuition: string; walkthrough: string }

async function main() {
  const contentPath = process.argv[2]
  const dryRun = process.argv.includes('--dry-run')
  if (!contentPath) {
    console.error('Usage: tsx apply-intuition-walkthrough.ts <path-to-content.json> [--dry-run]')
    process.exit(1)
  }

  const content: Record<string, ContentEntry> = JSON.parse(readFileSync(contentPath, 'utf8'))
  const slugs = Object.keys(content)
  console.log(`Loaded content for ${slugs.length} slugs.`)

  const problems = await prisma.problem.findMany({
    where: { status: ProblemStatus.published, slug: { in: slugs } },
  })
  console.log(`Matched ${problems.length} published problems in the DB.`)

  const dbSlugs = new Set(problems.map((p) => p.slug))
  const unmatched = slugs.filter((s) => !dbSlugs.has(s))
  if (unmatched.length > 0) {
    console.log('WARNING - slugs in content with no matching published problem:', unmatched)
  }

  let updated = 0
  for (const problem of problems) {
    const entry = content[problem.slug]
    if (!entry) continue

    if (!dryRun) {
      await prisma.problem.update({
        where: { id: problem.id },
        data: {
          intuition: entry.intuition,
          walkthrough: entry.walkthrough,
        },
      })
    }
    console.log(`  ${dryRun ? '[dry-run] would update' : 'updated'}: ${problem.title}`)
    updated++
  }

  console.log('Done.')
  console.log(`  Updated: ${updated}`)
}

main()
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
