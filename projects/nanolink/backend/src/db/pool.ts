import { Pool } from "pg";

type DbConfig = {
  connectionString?: string;
  host?: string;
  port?: number;
  user?: string;
  password?: string;
  database?: string;
  ssl?: { rejectUnauthorized: boolean; ca?: string } | undefined;
};

const requiredDbEnv = ["DB_HOST", "DB_USER", "DB_PASS", "DB_NAME"] as const;
const missingDbEnv = process.env.DATABASE_URL
  ? []
  : requiredDbEnv.filter((key) => !process.env[key]);

export const databaseConfigError =
  missingDbEnv.length > 0
    ? `Database is not configured. Missing: ${missingDbEnv.join(", ")}`
    : null;

const dbConfig: DbConfig = process.env.DATABASE_URL
  ? { connectionString: process.env.DATABASE_URL }
  : {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT ? Number(process.env.DB_PORT) : undefined,
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
      database: process.env.DB_NAME,
      ssl:
        process.env.DB_SSL === "true"
          ? { rejectUnauthorized: true, ca: process.env.DB_SSL_CA }
          : undefined,
    };

export const pool = new Pool(dbConfig);
