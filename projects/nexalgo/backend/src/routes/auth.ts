import { Router } from 'express'
import { authenticateRequest, type AuthenticatedRequest } from '../middleware/auth.js'

export const authRouter = Router()

authRouter.post('/auth/session', authenticateRequest, async (req: AuthenticatedRequest, res) => {
  const currentUser = req.currentUser!
  res.json({
    user: {
      id: currentUser.id,
      firebaseUid: currentUser.firebaseUid,
      email: currentUser.email,
      displayName: currentUser.displayName,
      roles: currentUser.appRoles,
    },
  })
})
