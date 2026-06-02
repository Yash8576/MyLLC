import { getApp, getApps, initializeApp } from 'firebase/app'
import type { Auth } from 'firebase/auth'
import { getAuth } from 'firebase/auth'

const firebaseConfig = {
  apiKey:
    process.env.NEXT_PUBLIC_NANOLINK_FIREBASE_API_KEY ??
    process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain:
    process.env.NEXT_PUBLIC_NANOLINK_FIREBASE_AUTH_DOMAIN ??
    'nanolink-c1bc5.firebaseapp.com',
  projectId:
    process.env.NEXT_PUBLIC_NANOLINK_FIREBASE_PROJECT_ID ?? 'nanolink-c1bc5',
  storageBucket:
    process.env.NEXT_PUBLIC_NANOLINK_FIREBASE_STORAGE_BUCKET ??
    'nanolink-c1bc5.firebasestorage.app',
  messagingSenderId:
    process.env.NEXT_PUBLIC_NANOLINK_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_NANOLINK_FIREBASE_APP_ID,
}

export const requiredNanolinkFirebaseEnvKeys = [
  'NEXT_PUBLIC_NANOLINK_FIREBASE_API_KEY',
  'NEXT_PUBLIC_NANOLINK_FIREBASE_MESSAGING_SENDER_ID',
  'NEXT_PUBLIC_NANOLINK_FIREBASE_APP_ID',
] as const

export const missingNanolinkFirebaseEnvKeys = requiredNanolinkFirebaseEnvKeys.filter((key) => {
  switch (key) {
    case 'NEXT_PUBLIC_NANOLINK_FIREBASE_API_KEY':
      return !firebaseConfig.apiKey
    case 'NEXT_PUBLIC_NANOLINK_FIREBASE_MESSAGING_SENDER_ID':
      return !firebaseConfig.messagingSenderId
    case 'NEXT_PUBLIC_NANOLINK_FIREBASE_APP_ID':
      return !firebaseConfig.appId
  }
})

export const nanolinkFirebaseConfigured = Object.values(firebaseConfig).every(Boolean)

const app = nanolinkFirebaseConfigured
  ? getApps().length > 0
    ? getApp()
    : initializeApp(firebaseConfig)
  : null

export const nanolinkAuth: Auth | null = app ? getAuth(app) : null
