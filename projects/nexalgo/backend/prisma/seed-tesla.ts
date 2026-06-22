// One-off seed runner for the Tesla interview question set.
// Usage: npx tsx prisma/seed-tesla.ts
//
// Upserts each problem by its canonical LeetCode URL (the unique identity for a
// question, per ProblemSource.normalizedUrl). If a problem with that URL already
// exists (e.g. seeded from another company's CSV), this merges the `companies`
// list instead of creating a duplicate row.

import { PrismaClient, ProblemStatus } from '@prisma/client'
import { teslaProblems } from './seed-data/tesla.js'

const prisma = new PrismaClient()

function buildSourceKey(platform: string, normalizedUrl: string) {
  return `${platform}:${normalizedUrl}`
}

function slugify(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

async function main() {
  let created = 0
  let updated = 0

  for (const entry of teslaProblems) {
    const platform = 'leetcode'
    const normalizedUrl = entry.link.replace(/\/+$/, '')
    const sourceKey = buildSourceKey(platform, normalizedUrl)

    const existingSource = await prisma.problemSource.findUnique({
      where: { sourceKey },
      include: { problem: true },
    })

    const solutionsJson = {
      python: entry.solutions.python,
      java: entry.solutions.java,
      cpp: entry.solutions.cpp,
    }

    if (existingSource) {
      const mergedCompanies = Array.from(
        new Set([...(existingSource.problem.companies as string[]), ...entry.companies]),
      )

      await prisma.problem.update({
        where: { id: existingSource.problem.id },
        data: {
          companies: mergedCompanies,
        },
      })

      updated += 1
      continue
    }

    const slug = slugify(entry.slug || entry.title)

    const problem = await prisma.problem.create({
      data: {
        problemNumber: entry.problemNumber,
        title: entry.title,
        slug,
        difficulty: entry.difficulty,
        problemStatement: entry.problemStatement,
        hints: entry.hints,
        intuition: entry.intuition,
        walkthrough: entry.walkthrough,
        complexityAnalysis: entry.complexityAnalysis,
        topics: entry.topics,
        companies: entry.companies,
        solutions: solutionsJson,
        status: ProblemStatus.published,
        publishedAt: new Date(),
      },
    })

    await prisma.problemSource.create({
      data: {
        problemId: problem.id,
        platform,
        slug: entry.slug,
        normalizedUrl,
        sourceKey,
      },
    })

    created += 1
  }

  console.log(`Seed complete. Created ${created} problems, merged companies into ${updated} existing problems.`)
}

main()
  .catch((error) => {
    console.error(error)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
