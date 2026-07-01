import {
  Prisma,
  ProblemProgressStatus,
  ProblemStatus,
  SubmissionStatus,
  SubmissionType,
  type Problem,
} from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { generateProblemContent } from './openai.js'

const scrapedProblemSchema = z.object({
  platform: z.string().min(1),
  externalId: z.string().optional(),
  slug: z.string().optional(),
  normalizedUrl: z.string().url(),
  title: z.string().min(1),
  problemNumber: z.number().int().positive().optional(),
  difficulty: z.string().optional(),
  problemStatement: z.string().min(1),
  topics: z.array(z.string()).default([]),
  companies: z.array(z.string()).default([]),
  hints: z.array(z.string()).default([]),
  intuition: z.string().optional(),
  walkthrough: z.string().optional(),
  complexityAnalysis: z.string().optional(),
  solutions: z
    .object({
      python: z.string().optional(),
      java: z.string().optional(),
      cpp: z.string().optional(),
    })
    .default({}),
})

export type ScrapedProblemInput = z.infer<typeof scrapedProblemSchema>

export function normalizeSubmissionInput(input: unknown) {
  return scrapedProblemSchema.parse(input)
}

export function buildSourceKey(input: {
  platform: string
  externalId?: string | null
  slug?: string | null
  normalizedUrl: string
}) {
  const identifier = input.externalId || input.slug || input.normalizedUrl
  return `${input.platform}:${identifier}`
}

function mapProblem(problem: Problem & { sources?: any[] }) {
  return {
    id: problem.id,
    problemNumber: problem.problemNumber,
    title: problem.title,
    slug: problem.slug,
    difficulty: problem.difficulty,
    problemStatement: problem.problemStatement,
    hints: problem.hints,
    intuition: problem.intuition,
    walkthrough: problem.walkthrough,
    complexityAnalysis: problem.complexityAnalysis,
    topics: problem.topics,
    companies: problem.companies,
    solutions: problem.solutions,
    status: problem.status,
    publishedAt: problem.publishedAt,
    sources: problem.sources ?? [],
  }
}

export async function listPublishedProblems() {
  const problems = await prisma.problem.findMany({
    where: { status: ProblemStatus.published },
    include: { sources: true },
    orderBy: [{ problemNumber: 'asc' }, { title: 'asc' }],
  })

  return problems.map(mapProblem)
}

export async function getProblemById(problemId: string) {
  const problem = await prisma.problem.findUnique({
    where: { id: problemId },
    include: { sources: true },
  })

  return problem ? mapProblem(problem) : null
}

export async function lookupProblem(input: ScrapedProblemInput) {
  const sourceKey = buildSourceKey(input)

  const source =
    (await prisma.problemSource.findUnique({
      where: { sourceKey },
      include: { problem: { include: { sources: true } } },
    })) ??
    (input.externalId
      ? await prisma.problemSource.findFirst({
          where: { platform: input.platform, externalId: input.externalId },
          include: { problem: { include: { sources: true } } },
        })
      : null) ??
    (input.slug
      ? await prisma.problemSource.findFirst({
          where: { platform: input.platform, slug: input.slug },
          include: { problem: { include: { sources: true } } },
        })
      : null) ??
    (await prisma.problemSource.findFirst({
      where: { normalizedUrl: input.normalizedUrl },
      include: { problem: { include: { sources: true } } },
    }))

  if (!source?.problem || source.problem.status !== ProblemStatus.published) {
    return null
  }

  return mapProblem(source.problem)
}

export async function createSubmission(
  userId: string,
  input: ScrapedProblemInput,
  targetProblemId?: string,
) {
  const existing = await lookupProblem(input)
  if (existing && !targetProblemId) {
    return { existingProblem: existing, submission: null }
  }

  const submission = await prisma.problemSubmission.create({
    data: {
      type: targetProblemId ? SubmissionType.update : SubmissionType.create,
      status: SubmissionStatus.pending,
      platform: input.platform,
      externalId: input.externalId,
      slug: input.slug,
      normalizedUrl: input.normalizedUrl,
      rawScrape: input as unknown as Prisma.InputJsonValue,
      proposedProblem: input as unknown as Prisma.InputJsonValue,
      submittedById: userId,
      targetProblemId,
    },
  })

  const generated = await generateProblemContent(input)

  await prisma.generatedContent.create({
    data: {
      submissionId: submission.id,
      status: SubmissionStatus.generated,
      hints: generated.hints as unknown as Prisma.InputJsonValue,
      intuition: generated.intuition,
      walkthrough: generated.walkthrough,
      complexity: generated.complexityAnalysis,
      pythonSolution: generated.pythonSolution,
      javaSolution: generated.javaSolution,
      cppSolution: generated.cppSolution,
    },
  })

  const updated = await prisma.problemSubmission.update({
    where: { id: submission.id },
    data: {
      status: SubmissionStatus.generated,
    },
    include: {
      generatedContent: true,
      submittedBy: true,
    },
  })

  return { existingProblem: null, submission: updated }
}

export async function listReviewQueue() {
  return prisma.problemSubmission.findMany({
    where: {
      status: {
        in: [SubmissionStatus.pending, SubmissionStatus.generated],
      },
    },
    include: {
      generatedContent: true,
      submittedBy: true,
      targetProblem: true,
    },
    orderBy: { createdAt: 'desc' },
  })
}

export async function approveSubmission(submissionId: string, reviewerId: string, notes?: string) {
  const submission = await prisma.problemSubmission.findUnique({
    where: { id: submissionId },
    include: { generatedContent: true },
  })

  if (!submission) {
    throw new Error('Submission not found.')
  }

  const proposedProblem = submission.proposedProblem as Prisma.JsonObject
  const generated = submission.generatedContent

  const slug = String(proposedProblem.slug ?? proposedProblem.title ?? submission.id)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')

  const problem = submission.targetProblemId
    ? await prisma.problem.update({
        where: { id: submission.targetProblemId },
        data: {
          title: String(proposedProblem.title),
          slug,
          difficulty: proposedProblem.difficulty ? String(proposedProblem.difficulty) : null,
          problemNumber:
            typeof proposedProblem.problemNumber === 'number'
              ? proposedProblem.problemNumber
              : null,
          problemStatement: String(proposedProblem.problemStatement ?? ''),
          topics: (proposedProblem.topics ?? []) as Prisma.InputJsonValue,
          companies: (proposedProblem.companies ?? []) as Prisma.InputJsonValue,
          hints: ((generated?.hints as Prisma.JsonValue | null) ??
            (proposedProblem.hints as Prisma.JsonValue | undefined) ??
            []) as Prisma.InputJsonValue,
          intuition: generated?.intuition ?? String(proposedProblem.intuition ?? ''),
          walkthrough: generated?.walkthrough ?? String(proposedProblem.walkthrough ?? ''),
          complexityAnalysis:
            generated?.complexity ?? String(proposedProblem.complexityAnalysis ?? ''),
          solutions: {
            python:
              generated?.pythonSolution ??
              String((proposedProblem.solutions as any)?.python ?? ''),
            java:
              generated?.javaSolution ?? String((proposedProblem.solutions as any)?.java ?? ''),
            cpp: generated?.cppSolution ?? String((proposedProblem.solutions as any)?.cpp ?? ''),
          } as Prisma.InputJsonValue,
          status: ProblemStatus.published,
          publishedAt: new Date(),
          publishedById: reviewerId,
        },
      })
    : await prisma.problem.create({
        data: {
          title: String(proposedProblem.title),
          slug,
          difficulty: proposedProblem.difficulty ? String(proposedProblem.difficulty) : null,
          problemNumber:
            typeof proposedProblem.problemNumber === 'number'
              ? proposedProblem.problemNumber
              : null,
          problemStatement: String(proposedProblem.problemStatement ?? ''),
          topics: (proposedProblem.topics ?? []) as Prisma.InputJsonValue,
          companies: (proposedProblem.companies ?? []) as Prisma.InputJsonValue,
          hints: ((generated?.hints as Prisma.JsonValue | null) ??
            (proposedProblem.hints as Prisma.JsonValue | undefined) ??
            []) as Prisma.InputJsonValue,
          intuition: generated?.intuition ?? String(proposedProblem.intuition ?? ''),
          walkthrough: generated?.walkthrough ?? String(proposedProblem.walkthrough ?? ''),
          complexityAnalysis:
            generated?.complexity ?? String(proposedProblem.complexityAnalysis ?? ''),
          solutions: {
            python:
              generated?.pythonSolution ??
              String((proposedProblem.solutions as any)?.python ?? ''),
            java:
              generated?.javaSolution ?? String((proposedProblem.solutions as any)?.java ?? ''),
            cpp: generated?.cppSolution ?? String((proposedProblem.solutions as any)?.cpp ?? ''),
          } as Prisma.InputJsonValue,
          status: ProblemStatus.published,
          publishedAt: new Date(),
          publishedById: reviewerId,
        },
      })

  await prisma.problemSource.upsert({
    where: {
      sourceKey: buildSourceKey(submission),
    },
    update: {
      platform: submission.platform,
      externalId: submission.externalId,
      slug: submission.slug,
      normalizedUrl: submission.normalizedUrl,
      problemId: problem.id,
    },
    create: {
      problemId: problem.id,
      platform: submission.platform,
      externalId: submission.externalId,
      slug: submission.slug,
      normalizedUrl: submission.normalizedUrl,
      sourceKey: buildSourceKey(submission),
    },
  })

  await prisma.problemSubmission.update({
    where: { id: submission.id },
    data: {
      status: SubmissionStatus.approved,
      reviewNotes: notes,
      reviewedAt: new Date(),
    },
  })

  await prisma.submissionReview.create({
    data: {
      submissionId: submission.id,
      reviewerId,
      action: 'approved',
      notes,
    },
  })

  return problem
}

export async function rejectSubmission(submissionId: string, reviewerId: string, notes?: string) {
  const submission = await prisma.problemSubmission.update({
    where: { id: submissionId },
    data: {
      status: SubmissionStatus.rejected,
      reviewNotes: notes,
      reviewedAt: new Date(),
    },
  })

  await prisma.submissionReview.create({
    data: {
      submissionId,
      reviewerId,
      action: 'rejected',
      notes,
    },
  })

  return submission
}

export async function regenerateSubmissionContent(submissionId: string) {
  const submission = await prisma.problemSubmission.findUnique({
    where: { id: submissionId },
  })

  if (!submission) {
    throw new Error('Submission not found.')
  }

  const input = normalizeSubmissionInput(submission.proposedProblem)
  const generated = await generateProblemContent(input)

  return prisma.generatedContent.upsert({
    where: { submissionId },
    update: {
      status: SubmissionStatus.generated,
      hints: generated.hints as unknown as Prisma.InputJsonValue,
      intuition: generated.intuition,
      walkthrough: generated.walkthrough,
      complexity: generated.complexityAnalysis,
      pythonSolution: generated.pythonSolution,
      javaSolution: generated.javaSolution,
      cppSolution: generated.cppSolution,
    },
    create: {
      submissionId,
      status: SubmissionStatus.generated,
      hints: generated.hints as unknown as Prisma.InputJsonValue,
      intuition: generated.intuition,
      walkthrough: generated.walkthrough,
      complexity: generated.complexityAnalysis,
      pythonSolution: generated.pythonSolution,
      javaSolution: generated.javaSolution,
      cppSolution: generated.cppSolution,
    },
  })
}

export async function upsertUserPreference(userId: string, defaultLanguage: string) {
  return prisma.userPreference.upsert({
    where: { userId },
    update: { defaultLanguage },
    create: {
      userId,
      defaultLanguage,
    },
  })
}

export async function listUserProgress(userId: string) {
  const records = await prisma.userProblemProgress.findMany({
    where: { userId },
    select: { problemId: true, status: true },
  })

  return records
}

function resolveProgressStatus(
  current: ProblemProgressStatus,
  requested: ProblemProgressStatus,
  allowSolvedDowngrade: boolean,
) {
  if (requested === ProblemProgressStatus.solved) return ProblemProgressStatus.solved
  if (requested === ProblemProgressStatus.attempted) {
    if (current === ProblemProgressStatus.solved && !allowSolvedDowngrade) {
      return ProblemProgressStatus.solved
    }
    return ProblemProgressStatus.attempted
  }
  if (requested === ProblemProgressStatus.visited) {
    return current === ProblemProgressStatus.unvisited ? ProblemProgressStatus.visited : current
  }
  return current
}

export async function upsertProblemProgress(
  userId: string,
  problemId: string,
  requestedStatus: ProblemProgressStatus,
  allowSolvedDowngrade = false,
) {
  const now = new Date()
  const progressKey = {
    userId_problemId: {
      userId,
      problemId,
    },
  }

  return prisma.$transaction(async (tx) => {
    const existing = await tx.userProblemProgress.findUnique({
      where: progressKey,
    })
    const currentStatus = existing?.status ?? ProblemProgressStatus.unvisited
    const status = resolveProgressStatus(currentStatus, requestedStatus, allowSolvedDowngrade)
    const attemptedAt =
      status === ProblemProgressStatus.attempted && !existing?.attemptedAt
        ? now
        : undefined
    const solvedAt =
      status === ProblemProgressStatus.solved
        ? now
        : existing?.status === ProblemProgressStatus.solved &&
            status === ProblemProgressStatus.attempted &&
            allowSolvedDowngrade
          ? null
          : undefined

    return tx.userProblemProgress.upsert({
      where: progressKey,
      update: {
        status,
        lastVisitedAt: now,
        attemptedAt,
        solvedAt,
      },
      create: {
        userId,
        problemId,
        status,
        lastVisitedAt: now,
        attemptedAt: status === ProblemProgressStatus.attempted ? now : undefined,
        solvedAt: status === ProblemProgressStatus.solved ? now : undefined,
      },
      select: {
        problemId: true,
        status: true,
      },
    })
  })
}
