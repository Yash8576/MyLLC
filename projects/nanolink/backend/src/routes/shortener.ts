import { Router } from "express";
import { nanoid } from "nanoid";

import { databaseConfigError, pool } from "../db/pool";
import { isValidUrl } from "../utils/validate";

const router = Router();

const DEFAULT_BASE_URL = "http://localhost:8080";

const buildShortUrl = (code: string) => {
  const base = (process.env.PUBLIC_BASE_URL ?? DEFAULT_BASE_URL).replace(/\/$/, "");
  return `${base}/r/${code}`;
};

const ensureDatabaseConfigured = (res: import("express").Response) => {
  if (!databaseConfigError) {
    return true;
  }

  res.status(503).json({ error: databaseConfigError });
  return false;
};

router.post("/api/shorten", async (req, res, next) => {
  try {
    if (!ensureDatabaseConfigured(res)) {
      return;
    }

    const longUrl = String(req.body?.longUrl ?? "").trim();

    if (!isValidUrl(longUrl)) {
      return res.status(400).json({ error: "Invalid URL" });
    }

    let code = "";
    for (let attempt = 0; attempt < 5; attempt += 1) {
      code = nanoid(7);
      try {
        await pool.query(
          "INSERT INTO urls (short_code, long_url) VALUES ($1, $2)",
          [code, longUrl]
        );
        const shortUrl = buildShortUrl(code);
        return res.status(201).json({ shortUrl, code, longUrl });
      } catch (error: unknown) {
        const pgError = error as { code?: string };
        if (pgError.code !== "23505") {
          throw error;
        }
      }
    }

    return res.status(500).json({ error: "Could not generate unique code" });
  } catch (error) {
    return next(error);
  }
});

router.get("/r/:code", async (req, res, next) => {
  try {
    if (!ensureDatabaseConfigured(res)) {
      return;
    }

    const code = req.params.code;
    const result = await pool.query(
      "SELECT long_url FROM urls WHERE short_code = $1",
      [code]
    );

    if (result.rowCount === 0) {
      return res.status(404).send("Not found");
    }

    await pool.query("UPDATE urls SET clicks = clicks + 1 WHERE short_code = $1", [
      code,
    ]);

    const longUrl = String(result.rows[0].long_url ?? "");
    if (!isValidUrl(longUrl)) {
      return res.status(410).send("Destination unavailable");
    }

    return res.redirect(302, longUrl);
  } catch (error) {
    return next(error);
  }
});

router.get("/api/analytics/:code", async (req, res, next) => {
  try {
    if (!ensureDatabaseConfigured(res)) {
      return;
    }

    const code = req.params.code;
    const result = await pool.query(
      "SELECT short_code, long_url, created_at, clicks FROM urls WHERE short_code = $1",
      [code]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Not found" });
    }

    return res.status(200).json({
      code: result.rows[0].short_code,
      longUrl: result.rows[0].long_url,
      createdAt: result.rows[0].created_at,
      clicks: result.rows[0].clicks,
    });
  } catch (error) {
    return next(error);
  }
});

export default router;
