import { getApp, getApps, initializeApp } from 'firebase/app'
import type { Auth } from 'firebase/auth'
import { getAuth } from 'firebase/auth'

const firebaseEnv = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

const firebaseConfig = {
  apiKey: firebaseEnv.apiKey ?? 'AIzaSyChiOs7D_dHdXY4aadUfJyB-6f6XFXPPwo',
  authDomain: firebaseEnv.authDomain ?? 'nexalgo-ace83.firebaseapp.com',
  projectId: firebaseEnv.projectId ?? 'nexalgo-ace83',
  storageBucket: firebaseEnv.storageBucket ?? 'nexalgo-ace83.firebasestorage.app',
  messagingSenderId: firebaseEnv.messagingSenderId ?? '140224951663',
  appId: firebaseEnv.appId ?? '1:140224951663:web:5c5ba53ca43443ff36a49a',
}

export const requiredFirebaseEnvKeys = [
  'NEXT_PUBLIC_FIREBASE_API_KEY',
  'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN',
  'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
  'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET',
  'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID',
  'NEXT_PUBLIC_FIREBASE_APP_ID',
] as const

export const missingFirebaseEnvKeys = requiredFirebaseEnvKeys.filter((key) => {
  switch (key) {
    case 'NEXT_PUBLIC_FIREBASE_API_KEY':
      return !firebaseEnv.apiKey
    case 'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN':
      return !firebaseEnv.authDomain
    case 'NEXT_PUBLIC_FIREBASE_PROJECT_ID':
      return !firebaseEnv.projectId
    case 'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET':
      return !firebaseEnv.storageBucket
    case 'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID':
      return !firebaseEnv.messagingSenderId
    case 'NEXT_PUBLIC_FIREBASE_APP_ID':
      return !firebaseEnv.appId
  }
})

export const firebaseClientConfigured = Object.values(firebaseConfig).every(Boolean)

const NEXALGO_APP_NAME = 'nexalgo'
const app = firebaseClientConfigured
  ? getApps().find((firebaseApp) => firebaseApp.name === NEXALGO_APP_NAME)
    ?? initializeApp(firebaseConfig, NEXALGO_APP_NAME)
  : null

export const auth: Auth | null = app ? getAuth(app) : null
