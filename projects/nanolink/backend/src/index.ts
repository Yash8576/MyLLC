import "dotenv/config";

import cors from "cors";
import express from "express";

import shortenerRoutes from "./routes/shortener";
import { errorHandler } from "./middleware/errorHandler";

const app = express();
const port = Number(process.env.PORT ?? "8080");
const corsOrigin = process.env.CORS_ORIGIN
  ? new URL(process.env.CORS_ORIGIN).origin
  : "*";

app.use(cors({ origin: corsOrigin }));
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true });
});

app.use(shortenerRoutes);
app.use(errorHandler);

app.listen(port, () => {
  console.log(`Nanolink API listening on ${port}`);
});
