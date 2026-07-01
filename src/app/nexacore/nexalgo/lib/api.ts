import type {
  LanguageKey,
  ProblemProgressRecord,
  ProblemProgressStatus,
  ProblemRecord,
  ReviewQueueItem,
  ScrapedProblemInput,
  SessionUser,
} from './types'

const apiBaseUrl =
  process.env.NEXT_PUBLIC_NEXALGO_API_BASE_URL?.replace(/\/+$/, '') ?? ''

export const nexalgoApiConfigured = apiBaseUrl.length > 0

async function request<T>(path: string, init?: RequestInit, idToken?: string): Promise<T> {
  if (!nexalgoApiConfigured) {
    throw new Error('NEXT_PUBLIC_NEXALGO_API_BASE_URL is not configured.')
  }

  const headers = new Headers(init?.headers)
  headers.set('Content-Type', 'application/json')
  if (idToken) {
    headers.set('Authorization', `Bearer ${idToken}`)
  }

  let response: Response

  try {
    response = await fetch(`${apiBaseUrl}${path}`, {
      ...init,
      headers,
    })
  } catch {
    throw new Error(
      `Unable to reach NexAlgo backend at ${apiBaseUrl}. Set NEXT_PUBLIC_NEXALGO_API_BASE_URL to the deployed Cloud Run /v1 URL.`,
    )
  }

  const json = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new Error(json.error || 'Request failed.')
  }

  return json as T
}

export const nexalgoApi = {
  apiBaseUrl,
  getProblems: async () =>
    request<{ problems: ProblemRecord[] }>('/problems').then((result) => result.problems),
  getProblem: async (problemId: string) =>
    request<{ problem: ProblemRecord }>(`/problems/${problemId}`).then((result) => result.problem),
  createSession: async (idToken: string) =>
    request<{ user: SessionUser }>('/auth/session', { method: 'POST', body: '{}' }, idToken).then(
      (result) => result.user,
    ),
  updatePreference: async (idToken: string, defaultLanguage: LanguageKey) =>
    request('/users/me/preferences', {
      method: 'PUT',
      body: JSON.stringify({ defaultLanguage }),
    }, idToken),
  updateProgress: async (
    idToken: string,
    problemId: string,
    status: ProblemProgressStatus,
    allowSolvedDowngrade = false,
  ) =>
    request<{ progress: ProblemProgressRecord }>(`/users/me/progress/${problemId}`, {
      method: 'PUT',
      body: JSON.stringify({ status, allowSolvedDowngrade }),
    }, idToken).then((result) => result.progress),
  getProgress: async (idToken: string) =>
    request<{ progress: ProblemProgressRecord[] }>(
      '/users/me/progress',
      undefined,
      idToken,
    ).then((result) => result.progress),
  getReviewQueue: async (idToken: string) =>
    request<{ submissions: ReviewQueueItem[] }>('/submissions', undefined, idToken).then(
      (result) => result.submissions,
    ),
  submitProblem: async (
    idToken: string,
    problem: ScrapedProblemInput,
    targetProblemId?: string,
  ) =>
    request('/submissions', {
      method: 'POST',
      body: JSON.stringify({ problem, targetProblemId }),
    }, idToken),
  approveSubmission: async (idToken: string, submissionId: string, notes?: string) =>
    request(`/submissions/${submissionId}/approve`, {
      method: 'POST',
      body: JSON.stringify({ notes }),
    }, idToken),
  rejectSubmission: async (idToken: string, submissionId: string, notes?: string) =>
    request(`/submissions/${submissionId}/reject`, {
      method: 'POST',
      body: JSON.stringify({ notes }),
    }, idToken),
  regenerateSubmission: async (idToken: string, submissionId: string) =>
    request(`/submissions/${submissionId}/regenerate`, {
      method: 'POST',
      body: JSON.stringify({}),
    }, idToken),
}
