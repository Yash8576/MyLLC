import { cert, getApp, getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { env } from '../config/env.js'

const clientEmail = env.FIREBASE_CLIENT_EMAIL
const privateKey = env.FIREBASE_PRIVATE_KEY

const app =
  getApps().length > 0
    ? getApp()
    : initializeApp(
        clientEmail && privateKey
          ? {
              credential: cert({
                projectId: env.FIREBASE_PROJECT_ID,
                clientEmail,
                privateKey: privateKey.replace(/\\n/g, '\n'),
              }),
            }
          : { projectId: env.FIREBASE_PROJECT_ID },
      )

export const adminAuth = getAuth(app)
