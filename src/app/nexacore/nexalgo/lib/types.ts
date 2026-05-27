export type LanguageKey = 'python' | 'java' | 'cpp'
export type ProblemProgressStatus = 'unvisited' | 'visited' | 'attempted' | 'solved'
export type AppRole = 'admin' | 'editor' | 'viewer'

export type ProblemSource = {
  id: string
  platform: string
  externalId?: string | null
  slug?: string | null
  normalizedUrl: string
  sourceKey: string
}

export type ProblemRecord = {
  id: string
  problemNumber?: number | null
  title: string
  slug: string
  difficulty?: string | null
  problemStatement: string
  hints: string[]
  intuition?: string | null
  walkthrough?: string | null
  complexityAnalysis?: string | null
  topics: string[]
  companies: string[]
  solutions: {
    python?: string
    java?: string
    cpp?: string
  }
  status: string
  publishedAt?: string | null
  sources: ProblemSource[]
}

export type SessionUser = {
  id: string
  firebaseUid: string
  email: string
  displayName?: string | null
  roles: AppRole[]
}

export type ReviewQueueItem = {
  id: string
  platform: string
  externalId?: string | null
  slug?: string | null
  normalizedUrl: string
  status: string
  type: string
  reviewNotes?: string | null
  createdAt: string
  submittedBy: {
    email: string
  }
  generatedContent?: {
    hints: string[]
    intuition?: string | null
    walkthrough?: string | null
    complexity?: string | null
    pythonSolution?: string | null
    javaSolution?: string | null
    cppSolution?: string | null
  } | null
  proposedProblem: ScrapedProblemInput
}

export type ScrapedProblemInput = {
  platform: string
  externalId?: string
  slug?: string
  normalizedUrl: string
  title: string
  problemNumber?: number
  difficulty?: string
  problemStatement: string
  topics: string[]
  companies: string[]
  hints?: string[]
  intuition?: string
  walkthrough?: string
  complexityAnalysis?: string
  solutions?: {
    python?: string
    java?: string
    cpp?: string
  }
}
