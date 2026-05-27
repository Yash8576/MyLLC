import cors from 'cors'
import express from 'express'
import helmet from 'helmet'
import morgan from 'morgan'
import { ZodError } from 'zod'
import { env } from './config/env.js'
import { authRouter } from './routes/auth.js'
import { healthRouter } from './routes/health.js'
import { problemsRouter } from './routes/problems.js'
import { submissionsRouter } from './routes/submissions.js'

export function createApp() {
  const app = express()

  app.use(helmet())
  app.use(
    cors({
      origin: env.CORS_ORIGIN.split(',').map((origin) => origin.trim()),
      credentials: false,
    }),
  )
  app.use(express.json({ limit: '2mb' }))
  app.use(morgan('dev'))

  app.use(healthRouter)
  app.use('/v1', authRouter)
  app.use('/v1', problemsRouter)
  app.use('/v1', submissionsRouter)

  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    if (error instanceof ZodError) {
      res.status(400).json({
        error: 'Invalid request payload.',
        details: error.flatten(),
      })
      return
    }

    const message = error instanceof Error ? error.message : 'Unexpected server error.'
    res.status(500).json({ error: message })
  })

  return app
}
