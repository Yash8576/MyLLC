import type { NextFunction, Request, Response } from "express";
import { cert, getApp, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const getAdminAuth = () => {
  if (!getApps().length) {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

    if (projectId && clientEmail && privateKey) {
      initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
    } else if (projectId) {
      // Fallback: verify tokens without a service account (works for same-project tokens)
      initializeApp({ projectId });
    } else {
      return null;
    }
  }
  return getAuth(getApp());
};

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      uid?: string;
    }
  }
}

/** Attaches req.uid when a valid Bearer token is present. */
export const optionalFirebaseAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return next();
  }

  const auth = getAdminAuth();
  if (!auth) {
    res.status(503).json({ error: "Firebase Admin is not configured" });
    return;
  }

  try {
    const token = header.slice(7);
    const decoded = await auth.verifyIdToken(token);
    req.uid = decoded.uid;
  } catch {
    res.status(401).json({ error: "Invalid authentication token" });
    return;
  }

  return next();
};

/** Rejects the request with 401 if no valid token is present. */
export const requireFirebaseAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  await optionalFirebaseAuth(req, res, async () => {
    if (!req.uid) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    next();
  });
};
