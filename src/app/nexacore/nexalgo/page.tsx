'use client'

import React, { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  type User,
} from 'firebase/auth'
import { auth, firebaseClientConfigured } from '@/app/nexacore/shared/firebase'
import { nexalgoApi } from './lib/api'
import type {
  LanguageKey,
  ProblemProgressStatus,
  ProblemRecord,
  ReviewQueueItem,
  ScrapedProblemInput,
  SessionUser,
} from './lib/types'
import './NexAlgo.css'

const LANGUAGE_OPTIONS: Array<{ value: LanguageKey; label: string }> = [
  { value: 'python', label: 'Python' },
  { value: 'java', label: 'Java' },
  { value: 'cpp', label: 'C++' },
]

const LANGUAGE_STORAGE_KEY = 'nexalgoDefaultLanguage'

type DraftFormState = {
  platform: string
  externalId: string
  slug: string
  normalizedUrl: string
  title: string
  problemNumber: string
  difficulty: string
  problemStatement: string
  topics: string
  companies: string
  hints: string
  intuition: string
  walkthrough: string
  complexityAnalysis: string
  python: string
  java: string
  cpp: string
}

function splitCsv(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
}

function splitLines(value: string) {
  return value
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean)
}

function emptyDraft(): DraftFormState {
  return {
    platform: 'leetcode',
    externalId: '',
    slug: '',
    normalizedUrl: '',
    title: '',
    problemNumber: '',
    difficulty: '',
    problemStatement: '',
    topics: '',
    companies: '',
    hints: '',
    intuition: '',
    walkthrough: '',
    complexityAnalysis: '',
    python: '',
    java: '',
    cpp: '',
  }
}

function draftFromProblem(problem: ProblemRecord): DraftFormState {
  const primarySource = problem.sources[0]

  return {
    platform: primarySource?.platform || 'leetcode',
    externalId: primarySource?.externalId || '',
    slug: primarySource?.slug || problem.slug,
    normalizedUrl: primarySource?.normalizedUrl || '',
    title: problem.title,
    problemNumber: problem.problemNumber ? String(problem.problemNumber) : '',
    difficulty: problem.difficulty || '',
    problemStatement: problem.problemStatement,
    topics: problem.topics.join(', '),
    companies: problem.companies.join(', '),
    hints: problem.hints.join('\n'),
    intuition: problem.intuition || '',
    walkthrough: problem.walkthrough || '',
    complexityAnalysis: problem.complexityAnalysis || '',
    python: problem.solutions.python || '',
    java: problem.solutions.java || '',
    cpp: problem.solutions.cpp || '',
  }
}

function buildDraftPayload(draft: DraftFormState): ScrapedProblemInput {
  return {
    platform: draft.platform.trim(),
    externalId: draft.externalId.trim() || undefined,
    slug: draft.slug.trim() || undefined,
    normalizedUrl: draft.normalizedUrl.trim(),
    title: draft.title.trim(),
    problemNumber: draft.problemNumber ? Number(draft.problemNumber) : undefined,
    difficulty: draft.difficulty.trim() || undefined,
    problemStatement: draft.problemStatement.trim(),
    topics: splitCsv(draft.topics),
    companies: splitCsv(draft.companies),
    hints: splitLines(draft.hints),
    intuition: draft.intuition.trim() || undefined,
    walkthrough: draft.walkthrough.trim() || undefined,
    complexityAnalysis: draft.complexityAnalysis.trim() || undefined,
    solutions: {
      python: draft.python,
      java: draft.java,
      cpp: draft.cpp,
    },
  }
}

function difficultyToneClass(difficulty?: string | null) {
  const normalized = difficulty?.trim().toLowerCase()
  if (normalized === 'easy') return 'nexalgo-difficulty-easy'
  if (normalized === 'medium') return 'nexalgo-difficulty-medium'
  if (normalized === 'hard') return 'nexalgo-difficulty-hard'
  return ''
}

function statusToneClass(status?: ProblemProgressStatus) {
  if (status === 'visited') return 'nexalgo-status-visited'
  if (status === 'attempted') return 'nexalgo-status-attempted'
  if (status === 'solved') return 'nexalgo-status-solved'
  return 'nexalgo-status-unvisited'
}

function CodeBlock({
  language,
  code,
}: {
  language: LanguageKey
  code: string
}) {
  return (
    <div className='nexalgo-code-block'>
      <div className='nexalgo-code-header'>
        <span>{LANGUAGE_OPTIONS.find((option) => option.value === language)?.label}</span>
      </div>
      <div className='nexalgo-code-body'>
        <pre className='nexalgo-code-content'>{code || '// Solution will appear after editorial approval.'}</pre>
      </div>
    </div>
  )
}

export default function NexAlgoPage() {
  const pathname = usePathname()
  const router = useRouter()
  const isProjectsRoute = pathname?.startsWith('/projects/')
  const backLinkHref = isProjectsRoute ? '/#projects' : '/'

  const [firebaseUser, setFirebaseUser] = useState<User | null>(null)
  const [sessionUser, setSessionUser] = useState<SessionUser | null>(null)
  const [authMode, setAuthMode] = useState<'login' | 'signup'>('signup')
  const [authForm, setAuthForm] = useState({
    email: '',
    password: '',
  })
  const [authMessage, setAuthMessage] = useState('')
  const [authError, setAuthError] = useState('')
  const [loading, setLoading] = useState(true)
  const [problems, setProblems] = useState<ProblemRecord[]>([])
  const [queue, setQueue] = useState<ReviewQueueItem[]>([])
  const [selectedProblemId, setSelectedProblemId] = useState<string>('')
  const [selectedLanguage, setSelectedLanguage] = useState<LanguageKey>('python')
  const [statusMap, setStatusMap] = useState<Record<string, ProblemProgressStatus>>({})
  const [showDraftModal, setShowDraftModal] = useState(false)
  const [draftError, setDraftError] = useState('')
  const [draftMessage, setDraftMessage] = useState('')
  const [draftMode, setDraftMode] = useState<'create' | 'update'>('create')
  const [draftForm, setDraftForm] = useState<DraftFormState>(emptyDraft())
  const [backendError, setBackendError] = useState('')

  useEffect(() => {
    if (pathname?.startsWith('/nexacore/')) {
      router.replace('/projects/nexalgo')
    }
  }, [pathname, router])

  useEffect(() => {
    const stored = window.localStorage.getItem(LANGUAGE_STORAGE_KEY) as LanguageKey | null
    if (stored && LANGUAGE_OPTIONS.some((option) => option.value === stored)) {
      setSelectedLanguage(stored)
    }
  }, [])

  useEffect(() => {
    async function bootstrapProblems() {
      try {
        const nextProblems = await nexalgoApi.getProblems()
        setProblems(nextProblems)
        if (nextProblems[0]) {
          setSelectedProblemId(nextProblems[0].id)
        }
        setBackendError('')
      } catch (error) {
        setBackendError(error instanceof Error ? error.message : 'Unable to load NexAlgo.')
      } finally {
        setLoading(false)
      }
    }

    void bootstrapProblems()
  }, [])

  useEffect(() => {
    if (!firebaseClientConfigured || !auth) {
      setLoading(false)
      return
    }

    const unsubscribe = onAuthStateChanged(auth, async (nextUser) => {
      setFirebaseUser(nextUser)
      setSessionUser(null)

      if (!nextUser) {
        return
      }

      try {
        const idToken = await nextUser.getIdToken()
        const user = await nexalgoApi.createSession(idToken)
        setSessionUser(user)
        setAuthMessage(`Signed in as ${user.email}`)
        setAuthError('')
      } catch (error) {
        setAuthError(error instanceof Error ? error.message : 'Unable to start session.')
      }
    })

    return () => unsubscribe()
  }, [])

  useEffect(() => {
    async function loadQueue() {
      if (!firebaseUser || !sessionUser?.roles.some((role) => role === 'admin' || role === 'editor')) {
        setQueue([])
        return
      }

      try {
        const idToken = await firebaseUser.getIdToken()
        const nextQueue = await nexalgoApi.getReviewQueue(idToken)
        setQueue(nextQueue)
      } catch (error) {
        setBackendError(error instanceof Error ? error.message : 'Unable to load queue.')
      }
    }

    void loadQueue()
  }, [firebaseUser, sessionUser])

  const selectedProblem = useMemo(
    () => problems.find((problem) => problem.id === selectedProblemId) ?? null,
    [problems, selectedProblemId],
  )

  const isEditor = !!sessionUser?.roles.some((role) => role === 'admin' || role === 'editor')
  const isSignedIn = !!firebaseUser && !!sessionUser

  async function handleLoginSubmit(event: React.FormEvent) {
    event.preventDefault()
    if (!auth) {
      setAuthError('Firebase Auth is not configured yet.')
      return
    }

    setAuthError('')
    setAuthMessage('')

    try {
      const credential = await signInWithEmailAndPassword(auth, authForm.email, authForm.password)
      setAuthMessage(`Welcome back, ${credential.user.email}`)
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : 'Unable to log in.')
    }
  }

  async function handleSignupSubmit(event: React.FormEvent) {
    event.preventDefault()
    if (!auth) {
      setAuthError('Firebase Auth is not configured yet.')
      return
    }

    setAuthError('')
    setAuthMessage('')

    try {
      const credential = await createUserWithEmailAndPassword(
        auth,
        authForm.email,
        authForm.password,
      )
      setAuthMessage(`Account created for ${credential.user.email}`)
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : 'Unable to create account.')
    }
  }

  async function handleLogout() {
    if (!auth) return
    await signOut(auth)
    setSessionUser(null)
    setAuthMessage('Signed out.')
  }

  async function persistLanguage(language: LanguageKey) {
    setSelectedLanguage(language)
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language)

    if (!firebaseUser) return

    const idToken = await firebaseUser.getIdToken()
    await nexalgoApi.updatePreference(idToken, language)
  }

  async function updateProgress(problemId: string, status: ProblemProgressStatus) {
    setStatusMap((current) => ({ ...current, [problemId]: status }))
    if (!firebaseUser) return

    const idToken = await firebaseUser.getIdToken()
    await nexalgoApi.updateProgress(idToken, problemId, status)
  }

  function openCreateDraft() {
    setDraftMode('create')
    setDraftError('')
    setDraftMessage('')
    setDraftForm(emptyDraft())
    setShowDraftModal(true)
  }

  function openRevisionDraft() {
    if (!selectedProblem) return
    setDraftMode('update')
    setDraftError('')
    setDraftMessage('')
    setDraftForm(draftFromProblem(selectedProblem))
    setShowDraftModal(true)
  }

  async function handleDraftSubmit(event: React.FormEvent) {
    event.preventDefault()
    if (!firebaseUser) {
      setDraftError('Sign in before submitting a draft.')
      return
    }

    setDraftError('')
    setDraftMessage('')

    try {
      const idToken = await firebaseUser.getIdToken()
      const payload = buildDraftPayload(draftForm)
      if (!payload.normalizedUrl) {
        throw new Error('Primary platform link is required.')
      }

      const result = await nexalgoApi.submitProblem(
        idToken,
        payload,
        draftMode === 'update' ? selectedProblem?.id : undefined,
      )

      if ((result as any).existingProblem) {
        setDraftMessage('This source is already published in NexAlgo.')
        return
      }

      setDraftMessage('Draft submitted to the NexAlgo review queue.')
      setShowDraftModal(false)

      if (isEditor) {
        const refreshedQueue = await nexalgoApi.getReviewQueue(idToken)
        setQueue(refreshedQueue)
      }
    } catch (error) {
      setDraftError(error instanceof Error ? error.message : 'Unable to submit draft.')
    }
  }

  async function handleApprove(submissionId: string) {
    if (!firebaseUser) return
    const idToken = await firebaseUser.getIdToken()
    await nexalgoApi.approveSubmission(idToken, submissionId)
    const [nextProblems, nextQueue] = await Promise.all([
      nexalgoApi.getProblems(),
      nexalgoApi.getReviewQueue(idToken),
    ])
    setProblems(nextProblems)
    setQueue(nextQueue)
    if (nextProblems[0] && !selectedProblemId) {
      setSelectedProblemId(nextProblems[0].id)
    }
  }

  async function handleReject(submissionId: string) {
    if (!firebaseUser) return
    const idToken = await firebaseUser.getIdToken()
    await nexalgoApi.rejectSubmission(idToken, submissionId)
    const nextQueue = await nexalgoApi.getReviewQueue(idToken)
    setQueue(nextQueue)
  }

  async function handleRegenerate(submissionId: string) {
    if (!firebaseUser) return
    const idToken = await firebaseUser.getIdToken()
    await nexalgoApi.regenerateSubmission(idToken, submissionId)
    const nextQueue = await nexalgoApi.getReviewQueue(idToken)
    setQueue(nextQueue)
  }

  if (pathname?.startsWith('/nexacore/')) {
    return null
  }

  if (!firebaseClientConfigured) {
    return (
      <div className='nexalgo-shell'>
        <header className='nexalgo-topbar'>
          <div className='nexalgo-topbar-left'>
            <Link href={backLinkHref} className='nexalgo-back-link'>
              <span aria-hidden='true'>&larr;</span>
              <span className='nexalgo-back-link-text'>Back to Projects</span>
            </Link>
          </div>
          <div className='nexalgo-brand'>
            <h1>NexAlgo</h1>
            <p>Firebase Auth + Cloud SQL</p>
          </div>
          <div className='nexalgo-topbar-right' />
        </header>
        <main className='nexalgo-auth-wrap'>
          <div className='nexalgo-auth-card'>
            <h2>Firebase Client Config Required</h2>
            <p className='nexalgo-detail-subcopy'>
              Set the new Firebase project values in `NEXT_PUBLIC_FIREBASE_*` env vars and point
              `NEXT_PUBLIC_NEXALGO_API_BASE_URL` to the new Cloud Run backend.
            </p>
          </div>
        </main>
      </div>
    )
  }

  return (
    <div className='nexalgo-shell'>
      <header className='nexalgo-topbar'>
        <div className='nexalgo-topbar-left'>
          <Link href={backLinkHref} className='nexalgo-back-link'>
            <span aria-hidden='true'>&larr;</span>
            <span className='nexalgo-back-link-text'>
              {isProjectsRoute ? 'Back to Projects' : 'Back to Nexacore'}
            </span>
          </Link>
        </div>
        <div className='nexalgo-brand'>
          <h1>NexAlgo</h1>
          <p>Cloud SQL + Firebase Auth</p>
        </div>
        <div className='nexalgo-topbar-right'>
          {isSignedIn ? (
            <button type='button' className='nexalgo-secondary-btn' onClick={handleLogout}>
              Logout
            </button>
          ) : null}
        </div>
      </header>

      {!isSignedIn ? (
        <main className='nexalgo-auth-wrap'>
          <div className='nexalgo-auth-card'>
            <div className='nexalgo-auth-grid'>
              <div className='nexalgo-auth-copy'>
                <h2>New NexAlgo Stack</h2>
                <p className='nexalgo-detail-subcopy'>
                  NexAlgo now treats Firebase as identity only. Questions, approvals, source
                  mappings, and user metadata belong in the backend and Cloud SQL.
                </p>
                <p className='nexalgo-detail-subcopy'>
                  API base URL: <code>{nexalgoApi.apiBaseUrl}</code>
                </p>
                {backendError ? <p className='nexalgo-error'>{backendError}</p> : null}
              </div>
              <form
                className='nexalgo-auth-form'
                onSubmit={authMode === 'login' ? handleLoginSubmit : handleSignupSubmit}>
                <h2>{authMode === 'login' ? 'Login' : 'Sign Up'}</h2>
                {authError ? <p className='nexalgo-error'>{authError}</p> : null}
                {authMessage ? <p className='nexalgo-message'>{authMessage}</p> : null}
                <input
                  type='email'
                  placeholder='Email address'
                  value={authForm.email}
                  onChange={(event) =>
                    setAuthForm((current) => ({ ...current, email: event.target.value }))
                  }
                />
                <input
                  type='password'
                  placeholder='Password'
                  value={authForm.password}
                  onChange={(event) =>
                    setAuthForm((current) => ({ ...current, password: event.target.value }))
                  }
                />
                <button type='submit'>{authMode === 'login' ? 'Login' : 'Create account'}</button>
                <button
                  type='button'
                  className='nexalgo-auth-switch'
                  onClick={() =>
                    setAuthMode((current) => (current === 'login' ? 'signup' : 'login'))
                  }>
                  {authMode === 'login'
                    ? 'Need an account? Create one'
                    : 'Already have an account? Log in'}
                </button>
              </form>
            </div>
          </div>
        </main>
      ) : (
        <main className='nexalgo-main'>
          <section className='nexalgo-list-pane nexalgo-list-pane-normal'>
            <div className='nexalgo-pane-head'>
              <div>
                <h2>Problem Library</h2>
                <p className='nexalgo-detail-subcopy'>
                  Published questions from the new backend and Cloud SQL.
                </p>
                <p className='nexalgo-detail-subcopy'>
                  Signed in as {sessionUser?.email} ({sessionUser?.roles.join(', ')})
                </p>
              </div>
              <div className='nexalgo-pane-controls'>
                <button type='button' className='nexalgo-pane-toggle' onClick={openCreateDraft}>
                  Submit draft
                </button>
              </div>
            </div>

            {loading ? <div className='nexalgo-empty-state'>Loading problems...</div> : null}
            {backendError ? <div className='nexalgo-empty-state'>{backendError}</div> : null}

            <div className='nexalgo-problem-list'>
              {problems.map((problem) => (
                <button
                  key={problem.id}
                  type='button'
                  className={`nexalgo-problem-card ${
                    selectedProblemId === problem.id ? 'active' : ''
                  }`}
                  onClick={() => {
                    setSelectedProblemId(problem.id)
                    void updateProgress(problem.id, 'visited')
                  }}>
                  <h3>
                    {problem.problemNumber ? `${problem.problemNumber}. ` : ''}
                    {problem.title}
                  </h3>
                  <p className={`nexalgo-meta-line ${difficultyToneClass(problem.difficulty)}`}>
                    {problem.difficulty || 'Difficulty pending'}
                  </p>
                  <p
                    className={`nexalgo-meta-line ${statusToneClass(
                      statusMap[problem.id] ?? 'unvisited',
                    )}`}>
                    {statusMap[problem.id] ?? 'unvisited'}
                  </p>
                  <p className='nexalgo-meta-line'>{problem.topics.join(', ') || 'No topics yet'}</p>
                </button>
              ))}
            </div>
          </section>

          <section className='nexalgo-detail-pane'>
            {!selectedProblem ? (
              <div className='nexalgo-empty-state'>No problem selected yet.</div>
            ) : (
              <div className='nexalgo-detail-body'>
                <div className='nexalgo-detail-title-row'>
                  <div>
                    <h2>
                      {selectedProblem.problemNumber
                        ? `${selectedProblem.problemNumber}. `
                        : ''}
                      {selectedProblem.title}
                    </h2>
                    <p className={`nexalgo-detail-subcopy ${difficultyToneClass(selectedProblem.difficulty)}`}>
                      {selectedProblem.difficulty || 'Difficulty pending'}
                    </p>
                  </div>
                  <div className='nexalgo-detail-actions'>
                    <button
                      type='button'
                      className='nexalgo-secondary-btn'
                      onClick={() => void updateProgress(selectedProblem.id, 'attempted')}>
                      Mark Attempted
                    </button>
                    <button
                      type='button'
                      className='nexalgo-save-btn'
                      onClick={() => void updateProgress(selectedProblem.id, 'solved')}>
                      Mark Solved
                    </button>
                    {isEditor ? (
                      <button type='button' className='nexalgo-link-btn' onClick={openRevisionDraft}>
                        Create revision draft
                      </button>
                    ) : null}
                  </div>
                </div>

                <div className='nexalgo-detail-sections'>
                  <section className='nexalgo-section'>
                    <h3>Problem statement</h3>
                    <p>{selectedProblem.problemStatement}</p>
                  </section>

                  <section className='nexalgo-section'>
                    <h3>Hints</h3>
                    <ul>
                      {selectedProblem.hints.map((hint) => (
                        <li key={hint}>{hint}</li>
                      ))}
                    </ul>
                  </section>

                  <section className='nexalgo-section'>
                    <h3>Topics</h3>
                    <div className='nexalgo-topic-row'>
                      {selectedProblem.topics.map((topic) => (
                        <span key={topic} className='nexalgo-chip'>
                          {topic}
                        </span>
                      ))}
                    </div>
                  </section>

                  <section className='nexalgo-section'>
                    <h3>Companies</h3>
                    <div className='nexalgo-company-row'>
                      {selectedProblem.companies.map((company) => (
                        <span key={company} className='nexalgo-chip'>
                          {company}
                        </span>
                      ))}
                    </div>
                  </section>

                  <section className='nexalgo-section'>
                    <h3>Intuition</h3>
                    <p>{selectedProblem.intuition || 'Editorial intuition will appear after review.'}</p>
                  </section>

                  <section className='nexalgo-section'>
                    <h3>Code walkthrough</h3>
                    <p>{selectedProblem.walkthrough || 'Walkthrough pending.'}</p>
                  </section>

                  <section className='nexalgo-section'>
                    <h3>Complexity analysis</h3>
                    <p>
                      {selectedProblem.complexityAnalysis || 'Complexity analysis pending.'}
                    </p>
                  </section>

                  <section className='nexalgo-section'>
                    <h3>Solutions</h3>
                    <div className='nexalgo-code-tabs'>
                      {LANGUAGE_OPTIONS.map((option) => (
                        <button
                          type='button'
                          key={option.value}
                          className={selectedLanguage === option.value ? 'active' : ''}
                          onClick={() => void persistLanguage(option.value)}>
                          {option.label}
                        </button>
                      ))}
                    </div>
                    <CodeBlock
                      language={selectedLanguage}
                      code={selectedProblem.solutions[selectedLanguage] || ''}
                    />
                  </section>

                  {isEditor ? (
                    <section className='nexalgo-section'>
                      <h3>Review queue</h3>
                      {queue.length === 0 ? (
                        <p>No pending drafts.</p>
                      ) : (
                        <div className='nexalgo-queue-list'>
                          {queue.map((submission) => (
                            <div key={submission.id} className='nexalgo-queue-card'>
                              <div className='nexalgo-queue-head'>
                                <div>
                                  <strong>{submission.proposedProblem.title}</strong>
                                  <p className='nexalgo-detail-subcopy'>
                                    {submission.platform} · {submission.type} · submitted by{' '}
                                    {submission.submittedBy.email}
                                  </p>
                                </div>
                                <span className='nexalgo-status-pill visited'>
                                  {submission.status}
                                </span>
                              </div>
                              <p className='nexalgo-detail-subcopy'>
                                {submission.proposedProblem.problemStatement.slice(0, 220)}
                                {submission.proposedProblem.problemStatement.length > 220 ? '…' : ''}
                              </p>
                              <div className='nexalgo-detail-actions'>
                                <button
                                  type='button'
                                  className='nexalgo-secondary-btn'
                                  onClick={() => void handleRegenerate(submission.id)}>
                                  Regenerate
                                </button>
                                <button
                                  type='button'
                                  className='nexalgo-danger-btn'
                                  onClick={() => void handleReject(submission.id)}>
                                  Reject
                                </button>
                                <button
                                  type='button'
                                  className='nexalgo-save-btn'
                                  onClick={() => void handleApprove(submission.id)}>
                                  Approve
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </section>
                  ) : null}
                </div>
              </div>
            )}
          </section>
        </main>
      )}

      {showDraftModal ? (
        <div className='nexalgo-modal-scrim'>
          <div className='nexalgo-modal-card nexalgo-question-modal'>
            <div className='nexalgo-menu-head'>
              <div>
                <h3>{draftMode === 'create' ? 'Submit question draft' : 'Create revision draft'}</h3>
                <p className='nexalgo-detail-subcopy'>
                  Drafts are stored in Cloud SQL and routed through the backend review queue.
                </p>
              </div>
              <button
                type='button'
                className='nexalgo-close-btn'
                onClick={() => setShowDraftModal(false)}>
                ×
              </button>
            </div>

            <form className='nexalgo-question-form' onSubmit={handleDraftSubmit}>
              {draftError ? <p className='nexalgo-error'>{draftError}</p> : null}
              {draftMessage ? <p className='nexalgo-message'>{draftMessage}</p> : null}

              <div className='nexalgo-question-grid'>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Platform</span>
                  <input
                    type='text'
                    value={draftForm.platform}
                    onChange={(event) =>
                      setDraftForm((current) => ({ ...current, platform: event.target.value }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Question number</span>
                  <input
                    type='number'
                    value={draftForm.problemNumber}
                    onChange={(event) =>
                      setDraftForm((current) => ({
                        ...current,
                        problemNumber: event.target.value,
                      }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Title</span>
                  <input
                    type='text'
                    value={draftForm.title}
                    onChange={(event) =>
                      setDraftForm((current) => ({ ...current, title: event.target.value }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Difficulty</span>
                  <input
                    type='text'
                    value={draftForm.difficulty}
                    onChange={(event) =>
                      setDraftForm((current) => ({ ...current, difficulty: event.target.value }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>External ID</span>
                  <input
                    type='text'
                    value={draftForm.externalId}
                    onChange={(event) =>
                      setDraftForm((current) => ({
                        ...current,
                        externalId: event.target.value,
                      }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Slug</span>
                  <input
                    type='text'
                    value={draftForm.slug}
                    onChange={(event) =>
                      setDraftForm((current) => ({ ...current, slug: event.target.value }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Primary platform link</span>
                  <input
                    type='text'
                    value={draftForm.normalizedUrl}
                    onChange={(event) =>
                      setDraftForm((current) => ({
                        ...current,
                        normalizedUrl: event.target.value,
                      }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Topics</span>
                  <input
                    type='text'
                    value={draftForm.topics}
                    onChange={(event) =>
                      setDraftForm((current) => ({ ...current, topics: event.target.value }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Companies</span>
                  <input
                    type='text'
                    value={draftForm.companies}
                    onChange={(event) =>
                      setDraftForm((current) => ({ ...current, companies: event.target.value }))
                    }
                  />
                </label>
              </div>

              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Problem statement</span>
                <textarea
                  value={draftForm.problemStatement}
                  onChange={(event) =>
                    setDraftForm((current) => ({
                      ...current,
                      problemStatement: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Hints</span>
                <textarea
                  value={draftForm.hints}
                  onChange={(event) =>
                    setDraftForm((current) => ({ ...current, hints: event.target.value }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Intuition</span>
                <textarea
                  value={draftForm.intuition}
                  onChange={(event) =>
                    setDraftForm((current) => ({ ...current, intuition: event.target.value }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Code walkthrough</span>
                <textarea
                  value={draftForm.walkthrough}
                  onChange={(event) =>
                    setDraftForm((current) => ({ ...current, walkthrough: event.target.value }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Complexity analysis</span>
                <textarea
                  value={draftForm.complexityAnalysis}
                  onChange={(event) =>
                    setDraftForm((current) => ({
                      ...current,
                      complexityAnalysis: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Python solution</span>
                <textarea
                  value={draftForm.python}
                  onChange={(event) =>
                    setDraftForm((current) => ({ ...current, python: event.target.value }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Java solution</span>
                <textarea
                  value={draftForm.java}
                  onChange={(event) =>
                    setDraftForm((current) => ({ ...current, java: event.target.value }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>C++ solution</span>
                <textarea
                  value={draftForm.cpp}
                  onChange={(event) =>
                    setDraftForm((current) => ({ ...current, cpp: event.target.value }))
                  }
                />
              </label>

              <div className='nexalgo-question-actions'>
                <button
                  type='button'
                  className='nexalgo-danger-btn'
                  onClick={() => setShowDraftModal(false)}>
                  Cancel
                </button>
                <button type='submit' className='nexalgo-save-btn'>
                  Submit draft
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}
