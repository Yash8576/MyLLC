import { AppRole } from '@prisma/client'
import { Router } from 'express'
import { z } from 'zod'
import {
  authenticateRequest,
  requireRole,
  type AuthenticatedRequest,
} from '../middleware/auth.js'
import {
  approveSubmission,
  createSubmission,
  listReviewQueue,
  normalizeSubmissionInput,
  regenerateSubmissionContent,
  rejectSubmission,
} from '../services/problems.js'

export const submissionsRouter = Router()

submissionsRouter.post('/submissions', authenticateRequest, async (req: AuthenticatedRequest, res) => {
  const schema = z.object({
    problem: z.unknown(),
    targetProblemId: z.string().optional(),
  })
  const body = schema.parse(req.body)
  const result = await createSubmission(
    req.currentUser!.id,
    normalizeSubmissionInput(body.problem),
    body.targetProblemId,
  )
  res.json(result)
})

submissionsRouter.get(
  '/submissions',
  authenticateRequest,
  requireRole([AppRole.admin, AppRole.editor]),
  async (_req, res) => {
    const submissions = await listReviewQueue()
    res.json({ submissions })
  },
)

submissionsRouter.post(
  '/submissions/:id/approve',
  authenticateRequest,
  requireRole([AppRole.admin, AppRole.editor]),
  async (req: AuthenticatedRequest, res) => {
    const schema = z.object({
      notes: z.string().optional(),
    })
    const body = schema.parse(req.body ?? {})
    const problem = await approveSubmission(String(req.params.id), req.currentUser!.id, body.notes)
    res.json({ problem })
  },
)

submissionsRouter.post(
  '/submissions/:id/reject',
  authenticateRequest,
  requireRole([AppRole.admin, AppRole.editor]),
  async (req: AuthenticatedRequest, res) => {
    const schema = z.object({
      notes: z.string().optional(),
    })
    const body = schema.parse(req.body ?? {})
    const submission = await rejectSubmission(String(req.params.id), req.currentUser!.id, body.notes)
    res.json({ submission })
  },
)

submissionsRouter.post(
  '/submissions/:id/regenerate',
  authenticateRequest,
  requireRole([AppRole.admin, AppRole.editor]),
  async (req: AuthenticatedRequest, res) => {
    const generatedContent = await regenerateSubmissionContent(String(req.params.id))
    res.json({ generatedContent })
  },
)
