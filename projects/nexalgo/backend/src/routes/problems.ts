import { Router } from 'express'
import { z } from 'zod'
import { asyncRoute } from '../middleware/asyncRoute.js'
import { authenticateRequest, type AuthenticatedRequest } from '../middleware/auth.js'
import {
  getProblemById,
  listPublishedProblems,
  listUserProgress,
  lookupProblem,
  normalizeSubmissionInput,
  upsertProblemProgress,
  upsertUserPreference,
} from '../services/problems.js'

export const problemsRouter = Router()

problemsRouter.get('/problems', asyncRoute(async (_req, res) => {
  const problems = await listPublishedProblems()
  res.json({ problems })
}))

problemsRouter.get('/problems/:id', asyncRoute(async (req, res) => {
  const problem = await getProblemById(String(req.params.id))
  if (!problem) {
    res.status(404).json({ error: 'Problem not found.' })
    return
  }
  res.json({ problem })
}))

problemsRouter.post('/problems/lookup', asyncRoute(async (req, res) => {
  const input = normalizeSubmissionInput(req.body)
  const problem = await lookupProblem(input)
  res.json({ problem })
}))

problemsRouter.put('/users/me/preferences', authenticateRequest, asyncRoute(async (req: AuthenticatedRequest, res) => {
  const schema = z.object({
    defaultLanguage: z.enum(['python', 'java', 'cpp']),
  })
  const body = schema.parse(req.body)
  const preference = await upsertUserPreference(req.currentUser!.id, body.defaultLanguage)
  res.json({ preference })
}))

problemsRouter.get(
  '/users/me/progress',
  authenticateRequest,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const progress = await listUserProgress(req.currentUser!.id)
    res.json({ progress })
  }),
)

problemsRouter.put(
  '/users/me/progress/:problemId',
  authenticateRequest,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const schema = z.object({
      status: z.enum(['unvisited', 'visited', 'attempted', 'solved']),
    })
    const body = schema.parse(req.body)
    const progress = await upsertProblemProgress(
      req.currentUser!.id,
      String(req.params.problemId),
      body.status,
    )
    res.json({ progress })
  }),
)
