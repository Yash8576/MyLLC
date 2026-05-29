import type { NextFunction, Request, Response } from 'express'
import { AppRole, type User } from '@prisma/client'
import { adminAuth } from '../lib/firebaseAdmin.js'
import { prisma } from '../lib/prisma.js'
import { env } from '../config/env.js'

type AuthenticatedRequest = Request & {
  currentUser?: User & { appRoles: AppRole[] }
}

const bootstrapRoles: Record<string, AppRole[]> = {
  'nexacoregloballlc@gmail.com': [AppRole.admin],
  'drvaiteja2004@gmail.com': [AppRole.editor],
}

function getBootstrapRoles(email: string) {
  const roles = new Set<AppRole>(bootstrapRoles[email.toLowerCase()] ?? [])

  if (env.NEXALGO_INITIAL_ADMIN_EMAIL?.toLowerCase() === email.toLowerCase()) {
    roles.add(AppRole.admin)
  }

  return Array.from(roles)
}

async function ensureBootstrapRoles(email: string, userId: string) {
  const roles = getBootstrapRoles(email)
  if (roles.length === 0) return

  await Promise.all(
    roles.map((role) =>
      prisma.role.upsert({
        where: {
          userId_role: {
            userId,
            role,
          },
        },
        update: {},
        create: {
          userId,
          role,
        },
      }),
    ),
  )
}

async function getUserWithRoles(userId: string) {
  return prisma.user.findUniqueOrThrow({
    where: { id: userId },
    include: {
      roles: true,
    },
  })
}

async function ensureViewerRole(user: User & { roles: Array<{ role: AppRole }> }) {
  if (user.roles.length !== 0) {
    return user
  }

  await prisma.role.create({
    data: {
      userId: user.id,
      role: AppRole.viewer,
    },
  })

  return getUserWithRoles(user.id)
}

async function ensureRuntimeRoles(email: string, user: User & { roles: Array<{ role: AppRole }> }) {
  await ensureBootstrapRoles(email, user.id)
  const refreshed = await getUserWithRoles(user.id)

  if (getBootstrapRoles(email).length > 0) {
    return refreshed
  }

  return ensureViewerRole(refreshed)
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

    const user = await prisma.user.upsert({
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

    const userWithRoles = await ensureRuntimeRoles(email, user)

    req.currentUser = {
      ...userWithRoles,
      appRoles: userWithRoles.roles.map((role: { role: AppRole }) => role.role),
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
