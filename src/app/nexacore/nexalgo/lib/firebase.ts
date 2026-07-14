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
  apiKey: firebaseEnv.apiKey ?? 'AIzaSyAUX-zIMiYyjHBEik2tXkP91jbxbH-4ojU',
  authDomain: firebaseEnv.authDomain ?? 'nexalgo-mig01.firebaseapp.com',
  projectId: firebaseEnv.projectId ?? 'nexalgo-mig01',
  storageBucket: firebaseEnv.storageBucket ?? 'nexalgo-mig01.firebasestorage.app',
  messagingSenderId: firebaseEnv.messagingSenderId ?? '335068424622',
  appId: firebaseEnv.appId ?? '1:335068424622:web:5a847f185fe6a532bd003f',
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
