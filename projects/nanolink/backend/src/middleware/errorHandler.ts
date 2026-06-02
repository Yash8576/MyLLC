import type { NextFunction, Request, Response } from "express";

export const errorHandler = (
  error: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) => {
  console.error(error);

  if (
    typeof error === "object" &&
    error !== null &&
    "type" in error &&
    error.type === "entity.parse.failed"
  ) {
    res.status(400).json({ error: "Malformed JSON request body" });
    return;
  }

  const detail =
    process.env.NODE_ENV === "production" || !(error instanceof Error)
      ? undefined
      : error.message;

  res.status(500).json({
    error: "Internal server error",
    ...(detail ? { detail } : {}),
  });
};
