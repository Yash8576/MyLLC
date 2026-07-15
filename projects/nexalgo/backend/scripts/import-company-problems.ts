// One-off bulk import: reads every "<Company>/5. All.csv" file from the
// leetcode-company-wise-problems resource dump and upserts bare-metadata
// Problem rows (title, difficulty, topics, link, companies) with NO
// AI-generated content. New problems land as `draft`; if a problem already
// exists (matched by its LeetCode URL / ProblemSource.sourceKey), only its
// `companies` array is extended - nothing else about it is touched.
//
// Run with: npx tsx scripts/import-company-problems.ts <path-to-resource-dir>

import { readdirSync, readFileSync, statSync } from 'node:fs'
import path from 'node:path'
import { PrismaClient, ProblemStatus, type Prisma } from '@prisma/client'

const prisma = new PrismaClient()

type Row = {
  title: string
  difficulty: string
  topics: string[]
  link: string
  company: string
}

// Minimal RFC4180-ish CSV line splitter: handles quoted fields containing commas.
function parseCsvLine(line: string): string[] {
  const cells: string[] = []
  let current = ''
  let inQuotes = false
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]
    if (inQuotes) {
      if (ch === '"') {
        if (line[i + 1] === '"') {
          current += '"'
          i++
        } else {
          inQuotes = false
        }
      } else {
        current += ch
      }
    } else if (ch === '"') {
      inQuotes = true
    } else if (ch === ',') {
      cells.push(current)
      current = ''
    } else {
      current += ch
    }
  }
  cells.push(current)
  return cells
}

function parseCsv(content: string): string[][] {
  return content
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0)
    .map(parseCsvLine)
}

function slugFromUrl(url: string): string | null {
  const match = url.match(/leetcode\.com\/problems\/([^/?#]+)/i)
  return match ? match[1].toLowerCase() : null
}

function buildSourceKey(platform: string, normalizedUrl: string) {
  return `${platform}:${normalizedUrl}`
}

async function main() {
  const resourceDir = process.argv[2]
  const dryRun = process.argv.includes('--dry-run')
  if (!resourceDir) {
    console.error('Usage: tsx import-company-problems.ts <path-to-resource-dir> [--dry-run]')
    process.exit(1)
  }

  const companyDirs = readdirSync(resourceDir).filter((name) => {
    const full = path.join(resourceDir, name)
    return statSync(full).isDirectory()
  })

  console.log(`Found ${companyDirs.length} company folders.`)

  // slug -> aggregated row data across all companies
  const bySlug = new Map<string, Row & { companies: Set<string> }>()
  let csvFilesRead = 0
  let rowsSeen = 0

  for (const company of companyDirs) {
    const csvPath = path.join(resourceDir, company, '5. All.csv')
    let content: string
    try {
      content = readFileSync(csvPath, 'utf8')
    } catch {
      continue
    }
    csvFilesRead++

    const rows = parseCsv(content)
    const header = rows[0]?.map((h) => h.trim().toLowerCase())
    if (!header) continue
    const idx = {
      difficulty: header.indexOf('difficulty'),
      title: header.indexOf('title'),
      link: header.indexOf('link'),
      topics: header.indexOf('topics'),
    }
    if (idx.title === -1 || idx.link === -1) continue

    for (const cells of rows.slice(1)) {
      const link = cells[idx.link]?.trim()
      const title = cells[idx.title]?.trim()
      if (!link || !title || !link.includes('leetcode.com/problems/')) continue

      const slug = slugFromUrl(link)
      if (!slug) continue

      rowsSeen++
      const difficulty = (cells[idx.difficulty] || '').trim()
      const topics = (cells[idx.topics] || '')
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean)
      const normalizedLink = `https://leetcode.com/problems/${slug}`

      const existing = bySlug.get(slug)
      if (existing) {
        existing.companies.add(company)
      } else {
        bySlug.set(slug, {
          title,
          difficulty,
          topics,
          link: normalizedLink,
          company,
          companies: new Set([company]),
        })
      }
    }
  }

  console.log(`Read ${csvFilesRead} CSV files, ${rowsSeen} rows, ${bySlug.size} unique problems.`)

  if (dryRun) {
    const sample = Array.from(bySlug.entries()).slice(0, 5)
    for (const [slug, row] of sample) {
      console.log(
        `  sample: ${slug} | ${row.title} | ${row.difficulty} | topics=${row.topics.join('|')} | companies=${Array.from(row.companies).join(',')} | ${row.link}`,
      )
    }
    console.log('Dry run only - no DB writes performed.')
    return
  }

  let created = 0
  let companiesAdded = 0
  let unchanged = 0
  let processed = 0

  for (const [slug, row] of bySlug) {
    processed++
    const normalizedUrl = row.link
    const sourceKey = buildSourceKey('leetcode', normalizedUrl)

    const source = await prisma.problemSource.findUnique({
      where: { sourceKey },
      include: { problem: true },
    })

    if (source?.problem) {
      const currentCompanies = new Set(
        Array.isArray(source.problem.companies) ? (source.problem.companies as string[]) : [],
      )
      const before = currentCompanies.size
      for (const c of row.companies) currentCompanies.add(c)

      if (currentCompanies.size > before) {
        await prisma.problem.update({
          where: { id: source.problem.id },
          data: { companies: Array.from(currentCompanies) as unknown as Prisma.InputJsonValue },
        })
        companiesAdded++
      } else {
        unchanged++
      }
      continue
    }

    // Brand new problem: bare metadata only, no generated content.
    const problem = await prisma.problem.create({
      data: {
        title: row.title,
        slug,
        difficulty: row.difficulty || null,
        problemStatement: '',
        hints: [] as unknown as Prisma.InputJsonValue,
        topics: row.topics as unknown as Prisma.InputJsonValue,
        companies: Array.from(row.companies) as unknown as Prisma.InputJsonValue,
        solutions: {} as unknown as Prisma.InputJsonValue,
        status: ProblemStatus.draft,
      },
    })

    await prisma.problemSource.create({
      data: {
        problemId: problem.id,
        platform: 'leetcode',
        slug,
        normalizedUrl,
        sourceKey,
      },
    })

    created++

    if (processed % 200 === 0) {
      console.log(`  ...${processed}/${bySlug.size} processed`)
    }
  }

  console.log('Done.')
  console.log(`  Created (new draft problems): ${created}`)
  console.log(`  Existing problems, companies extended: ${companiesAdded}`)
  console.log(`  Existing problems, no change needed: ${unchanged}`)
}

main()
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
