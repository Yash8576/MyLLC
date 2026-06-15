import { getApp, getApps, initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'
import { getFirestore } from 'firebase/firestore'

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_TODO_FIREBASE_API_KEY ?? 'AIzaSyD2LXtQ00F3Wt9tCxwHZjTXTQbAKMpRUuU',
  authDomain: process.env.NEXT_PUBLIC_TODO_FIREBASE_AUTH_DOMAIN ?? 'buzz-to-do.firebaseapp.com',
  projectId: process.env.NEXT_PUBLIC_TODO_FIREBASE_PROJECT_ID ?? 'buzz-to-do',
  storageBucket: process.env.NEXT_PUBLIC_TODO_FIREBASE_STORAGE_BUCKET ?? 'buzz-to-do.firebasestorage.app',
  messagingSenderId: process.env.NEXT_PUBLIC_TODO_FIREBASE_MESSAGING_SENDER_ID ?? '605272755203',
  appId: process.env.NEXT_PUBLIC_TODO_FIREBASE_APP_ID ?? '1:605272755203:web:987dfee84dc0c72b205236',
}

const TODO_APP_NAME = 'todo'
const app = getApps().find(a => a.name === TODO_APP_NAME)
  ?? initializeApp(firebaseConfig, TODO_APP_NAME)

export const auth = getAuth(app)
export const db   = getFirestore(app)
