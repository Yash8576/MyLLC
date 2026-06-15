'use client'

import Link from 'next/link'
import { FormEvent, useEffect, useState } from 'react'
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  type User,
} from 'firebase/auth'
import {
  missingNanolinkFirebaseEnvKeys,
  nanolinkAuth,
  nanolinkFirebaseConfigured,
} from './lib/firebase'
import './Nanolink.css'

type SavedLink = {
  shortUrl: string
  longUrl: string
  code: string
  createdAt: string
}

const apiBaseUrl = (
  process.env.NEXT_PUBLIC_NANOLINK_API_BASE_URL ??
  'https://nanolink-backend-837491606409.us-east4.run.app'
).replace(/\/$/, '')

const getIdToken = async (user: User) => {
  try {
    return await user.getIdToken()
  } catch {
    return null
  }
}

export default function NanolinkPage() {
  const [menuOpen, setMenuOpen] = useState(false)
  const [authOpen, setAuthOpen] = useState(false)
  const [historyOpen, setHistoryOpen] = useState(false)
  const [authMode, setAuthMode] = useState<'login' | 'signup'>('login')
  const [user, setUser] = useState<User | null>(null)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [authError, setAuthError] = useState('')
  const [longUrl, setLongUrl] = useState('')
  const [shortUrl, setShortUrl] = useState('')
  const [shortening, setShortening] = useState(false)
  const [shortenError, setShortenError] = useState('')
  const [history, setHistory] = useState<SavedLink[]>([])
  const [historyLoading, setHistoryLoading] = useState(false)
  const [historyError, setHistoryError] = useState('')

  useEffect(() => {
    if (!nanolinkAuth) {
      return
    }

    return onAuthStateChanged(nanolinkAuth, (nextUser) => {
      setUser(nextUser)
      if (nextUser) {
        setAuthOpen(false)
      } else {
        setHistory([])
      }
    })
  }, [])

  async function fetchHistory(currentUser: User) {
    setHistoryLoading(true)
    setHistoryError('')

    try {
      const token = await getIdToken(currentUser)
      const response = await fetch(`${apiBaseUrl}/api/links`, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      })
      const data = (await response.json()) as {
        links?: SavedLink[]
        error?: string
      }

      if (!response.ok || !data.links) {
        throw new Error(data.error ?? 'Could not load history')
      }

      setHistory(data.links)
    } catch (error) {
      setHistoryError(error instanceof Error ? error.message : 'Could not load history')
    } finally {
      setHistoryLoading(false)
    }
  }

  async function handleShorten(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setShortenError('')
    setShortUrl('')
    setShortening(true)

    try {
      const token = user ? await getIdToken(user) : null
      const response = await fetch(`${apiBaseUrl}/api/shorten`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ longUrl }),
      })
      const responseText = await response.text()
      const data = (responseText
        ? JSON.parse(responseText)
        : {}) as {
        shortUrl?: string
        longUrl?: string
        code?: string
        error?: string
      }

      if (!response.ok || !data.shortUrl || !data.code || !data.longUrl) {
        throw new Error(data.error ?? `Could not shorten URL (${response.status})`)
      }

      const savedLink: SavedLink = {
        shortUrl: data.shortUrl,
        longUrl: data.longUrl,
        code: data.code,
        createdAt: new Date().toISOString(),
      }

      setShortUrl(savedLink.shortUrl)
      if (user) {
        setHistory((previousHistory) => [savedLink, ...previousHistory])
      }
    } catch (error) {
      setShortenError(error instanceof Error ? error.message : 'Could not shorten URL')
    } finally {
      setShortening(false)
    }
  }

  async function handleAuth(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setAuthError('')

    if (!nanolinkAuth) {
      setAuthError(
        `Firebase is not configured. Missing: ${missingNanolinkFirebaseEnvKeys.join(', ')}`,
      )
      return
    }

    try {
      if (authMode === 'signup') {
        await createUserWithEmailAndPassword(nanolinkAuth, email, password)
      } else {
        await signInWithEmailAndPassword(nanolinkAuth, email, password)
      }
      setPassword('')
      setEmail('')
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : 'Authentication failed')
    }
  }

  function openAuth(mode: 'login' | 'signup') {
    setAuthMode(mode)
    setAuthOpen(true)
    setMenuOpen(false)
  }

  function openHistory() {
    setHistoryOpen(true)
    setMenuOpen(false)
    if (user) {
      void fetchHistory(user)
    }
  }

  return (
    <main className='nanolink-page'>
      <header className='nanolink-topbar'>
        <div className='nanolink-topbar-inner'>
          <div className='nanolink-topbar-left'>
            <Link href='/#projects' className='back-to-nexacore'>
              <svg
                width='24'
                height='24'
                viewBox='0 0 24 24'
                fill='none'
                stroke='currentColor'
                strokeWidth='2'
                strokeLinecap='round'
                strokeLinejoin='round'>
                <path d='M19 12H5' />
                <path d='M12 19l-7-7 7-7' />
              </svg>
              <span className="back-label">Back to Projects</span>
            </Link>
          </div>
          <Link href='/#projects' className='nanolink-brand'>
            <span className='nanolink-brand-mark'>N</span>
            Nanolink
          </Link>
          <div className='nanolink-menu-wrap'>
            <button
              aria-label={menuOpen ? 'Close menu' : 'Open menu'}
              aria-expanded={menuOpen}
              className='nanolink-icon-button nanolink-hamburger'
              type='button'
              onClick={() => setMenuOpen((open) => !open)}>
              {menuOpen ? (
                <svg width='18' height='18' viewBox='0 0 18 18' fill='none' stroke='currentColor' strokeWidth='2' strokeLinecap='round'>
                  <line x1='2' y1='2' x2='16' y2='16' />
                  <line x1='16' y1='2' x2='2' y2='16' />
                </svg>
              ) : (
                <svg width='18' height='18' viewBox='0 0 18 18' fill='none' stroke='currentColor' strokeWidth='2' strokeLinecap='round'>
                  <line x1='2' y1='4' x2='16' y2='4' />
                  <line x1='2' y1='9' x2='16' y2='9' />
                  <line x1='2' y1='14' x2='16' y2='14' />
                </svg>
              )}
            </button>
            {menuOpen ? (
              <div className='nanolink-menu'>
                {user ? (
                  <>
                    <button
                      className='nanolink-menu-item'
                      type='button'
                      onClick={openHistory}>
                      History
                    </button>
                    <button
                      className='nanolink-menu-item'
                      type='button'
                      onClick={() => {
                        if (nanolinkAuth) {
                          void signOut(nanolinkAuth)
                        }
                        setMenuOpen(false)
                      }}>
                      Sign out
                    </button>
                  </>
                ) : (
                  <>
                    <button
                      className='nanolink-menu-item'
                      type='button'
                      onClick={() => openAuth('login')}>
                      Login
                    </button>
                    <button
                      className='nanolink-menu-item'
                      type='button'
                      onClick={() => openAuth('signup')}>
                      Sign up
                    </button>
                  </>
                )}
              </div>
            ) : null}
          </div>
        </div>
      </header>

      <section className='nanolink-hero'>
        <div className='nanolink-hero-inner'>
          <p className='nanolink-eyebrow'>Nexacore URL shortener</p>
          <h1 className='nanolink-title'>Short links that stay clean.</h1>
          <p className='nanolink-subtitle'>
            Paste any long URL and get a compact Nanolink. You can shorten without an
            account; sign in when you want your recent links saved in history.
          </p>

          <form className='nanolink-shortener' onSubmit={handleShorten}>
            <div className='nanolink-url-row'>
              <input
                className='nanolink-url-input'
                inputMode='url'
                onChange={(event) => setLongUrl(event.target.value)}
                placeholder='Paste your URL'
                required
                type='url'
                value={longUrl}
              />
              <button className='nanolink-primary-button' disabled={shortening} type='submit'>
                {shortening ? 'Shortening...' : 'Shorten URL'}
              </button>
            </div>
            {shortenError ? <p className='nanolink-error'>{shortenError}</p> : null}
            {!user ? (
              <p className='nanolink-hint'>
                Anonymous links work now. Login or sign up to keep history.
              </p>
            ) : (
              <p className='nanolink-hint'>Signed in as {user.email}. New links will appear in History.</p>
            )}
            {shortUrl ? (
              <div className='nanolink-result'>
                <a href={shortUrl} rel='noreferrer' target='_blank'>
                  {shortUrl}
                </a>
                <button
                  className='nanolink-secondary-button'
                  type='button'
                  onClick={() => navigator.clipboard.writeText(shortUrl)}>
                  Copy
                </button>
              </div>
            ) : null}
          </form>
        </div>
      </section>

      {authOpen ? (
        <div className='nanolink-panel-overlay'>
          <aside className='nanolink-panel' aria-label='Authentication'>
            <div className='nanolink-panel-header'>
              <h2>{authMode === 'signup' ? 'Sign up' : 'Login'}</h2>
              <button
                className='nanolink-icon-button'
                type='button'
                onClick={() => setAuthOpen(false)}>
                X
              </button>
            </div>
            <form className='nanolink-auth-form' onSubmit={handleAuth}>
              {!nanolinkFirebaseConfigured ? (
                <p className='nanolink-error'>
                  Firebase is not configured. Missing: {missingNanolinkFirebaseEnvKeys.join(', ')}
                </p>
              ) : null}
              <input
                className='nanolink-auth-input'
                disabled={!nanolinkFirebaseConfigured}
                onChange={(event) => setEmail(event.target.value)}
                placeholder='Email'
                required
                type='email'
                value={email}
              />
              <input
                className='nanolink-auth-input'
                disabled={!nanolinkFirebaseConfigured}
                minLength={6}
                onChange={(event) => setPassword(event.target.value)}
                placeholder='Password'
                required
                type='password'
                value={password}
              />
              {authError ? <p className='nanolink-error'>{authError}</p> : null}
              <button
                className='nanolink-primary-button'
                disabled={!nanolinkFirebaseConfigured}
                type='submit'>
                {authMode === 'signup' ? 'Create account' : 'Login'}
              </button>
            </form>
            <p className='nanolink-auth-switch'>
              {authMode === 'signup' ? 'Already have an account? ' : 'Need an account? '}
              <button
                className='nanolink-text-button'
                type='button'
                onClick={() => setAuthMode(authMode === 'signup' ? 'login' : 'signup')}>
                {authMode === 'signup' ? 'Login' : 'Sign up'}
              </button>
            </p>
          </aside>
        </div>
      ) : null}

      {historyOpen ? (
        <div className='nanolink-panel-overlay'>
          <aside className='nanolink-panel' aria-label='History'>
            <div className='nanolink-panel-header'>
              <h2>History</h2>
              <button
                className='nanolink-icon-button'
                type='button'
                onClick={() => setHistoryOpen(false)}>
                X
              </button>
            </div>
            <div className='nanolink-history-list'>
              {historyLoading ? (
                <p className='nanolink-hint'>Loading...</p>
              ) : historyError ? (
                <p className='nanolink-error'>{historyError}</p>
              ) : history.length ? (
                history.map((item) => (
                  <article className='nanolink-history-card' key={`${item.code}-${item.createdAt}`}>
                    <a href={item.shortUrl} rel='noreferrer' target='_blank'>
                      {item.shortUrl}
                    </a>
                    <p>{item.longUrl}</p>
                  </article>
                ))
              ) : (
                <p className='nanolink-hint'>No saved links yet.</p>
              )}
            </div>
          </aside>
        </div>
      ) : null}
    </main>
  )
}
