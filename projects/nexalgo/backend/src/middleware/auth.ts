import type { NextFunction, Request, Response } from 'express'
import { AppRole, type User } from '@prisma/client'
import { adminAuth } from '../lib/firebaseAdmin.js'
import { prisma } from '../lib/prisma.js'
import { env } from '../config/env.js'

type AuthenticatedRequest = Request & {
  currentUser?: User & { appRoles: AppRole[] }
}

async function ensureBootstrapAdmin(email: string, userId: string) {
  if (!env.NEXALGO_INITIAL_ADMIN_EMAIL) return
  if (email.toLowerCase() !== env.NEXALGO_INITIAL_ADMIN_EMAIL.toLowerCase()) return

  await prisma.role.upsert({
    where: {
      userId_role: {
        userId,
        role: AppRole.admin,
      },
    },
    update: {},
    create: {
      userId,
      role: AppRole.admin,
    },
  })
}

export async function authenticateRequest(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
) {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing bearer token.' })
    return
  }

  const token = authHeader.slice('Bearer '.length)

  try {
    const decodedToken = await adminAuth.verifyIdToken(token)
    const email = decodedToken.email?.toLowerCase()
    if (!email) {
      res.status(401).json({ error: 'Firebase user email is required.' })
      return
    }

    let user = await prisma.user.upsert({
      where: { firebaseUid: decodedToken.uid },
      update: {
        email,
        displayName: decodedToken.name ?? undefined,
      },
      create: {
        firebaseUid: decodedToken.uid,
        email,
        displayName: decodedToken.name ?? null,
      },
      include: {
        roles: true,
      },
    })

    await ensureBootstrapAdmin(email, user.id)

    if (user.roles.length === 0) {
      await prisma.role.create({
        data: {
          userId: user.id,
          role: AppRole.viewer,
        },
      })
      user = await prisma.user.findUniqueOrThrow({
        where: { id: user.id },
        include: { roles: true },
      })
    }

    req.currentUser = {
      ...user,
      appRoles: user.roles.map((role: { role: AppRole }) => role.role),
    }
    next()
  } catch (error) {
    res.status(401).json({ error: 'Invalid Firebase token.' })
  }
}

export function requireRole(roles: AppRole[]) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    const currentUser = req.currentUser
    if (!currentUser) {
      res.status(401).json({ error: 'Authentication required.' })
      return
    }

    if (!currentUser.appRoles.some((role: AppRole) => roles.includes(role))) {
      res.status(403).json({ error: 'Insufficient permissions.' })
      return
    }

    next()
  }
}

export type { AuthenticatedRequest }
