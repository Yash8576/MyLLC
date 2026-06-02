import { initializeApp, getApps } from "firebase/app";
import { Auth, getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
};

let authInstance: Auth | null = null;

export const firebaseConfigError =
  !firebaseConfig.apiKey ||
  firebaseConfig.apiKey.startsWith("replace-") ||
  !firebaseConfig.authDomain ||
  firebaseConfig.authDomain.startsWith("replace-") ||
  !firebaseConfig.projectId ||
  firebaseConfig.projectId.startsWith("replace-") ||
  !firebaseConfig.appId ||
  firebaseConfig.appId.startsWith("replace-")
    ? "Firebase is not configured. Add frontend/.env.local with your Firebase web app values."
    : null;

export const getClientAuth = () => {
  if (typeof window === "undefined") {
    throw new Error("Firebase Auth is only available in the browser.");
  }

  if (firebaseConfigError) {
    throw new Error(firebaseConfigError);
  }

  if (!authInstance) {
    const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
    authInstance = getAuth(app);
  }

  return authInstance;
};
