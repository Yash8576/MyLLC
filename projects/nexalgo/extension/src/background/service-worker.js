import '../config.js'

const state = {
  latestPayload: null,
  latestLookup: null,
  latestError: '',
  latestSubmission: null,
  latestMessage: '',
}

chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch(() => {
  // Chrome may reject this during transient service worker startup states.
})

async function getConfig() {
  const defaults = globalThis.NEXALGO_EXTENSION_CONFIG

  return {
    apiBaseUrl: defaults.apiBaseUrl.replace(/\/+$/, ''),
    webBaseUrl: defaults.webBaseUrl.replace(/\/+$/, ''),
    firebaseApiKey: defaults.firebaseApiKey,
  }
}

async function getStoredSession() {
  const { nexalgoAuth } = await chrome.storage.local.get('nexalgoAuth')
  return nexalgoAuth ?? null
}

async function setStoredSession(session) {
  if (session) {
    await chrome.storage.local.set({ nexalgoAuth: session })
  } else {
    await chrome.storage.local.remove('nexalgoAuth')
  }
}

async function refreshSession(session) {
  const { firebaseApiKey } = await getConfig()
  if (!session?.refreshToken || !firebaseApiKey) {
    return session
  }

  if (session.expiresAt && session.expiresAt - Date.now() > 60_000) {
    return session
  }

  const response = await fetch(`https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(firebaseApiKey)}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: session.refreshToken,
    }),
  })

  const json = await response.json().catch(() => ({}))
  if (!response.ok) {
    await setStoredSession(null)
    throw new Error('Your NexAlgo session expired. Sign in again.')
  }

  const refreshed = {
    email: session.email,
    idToken: json.id_token,
    refreshToken: json.refresh_token || session.refreshToken,
    expiresAt: Date.now() + Number(json.expires_in || 3600) * 1000,
  }
  await setStoredSession(refreshed)
  return refreshed
}

async function firebaseAuth(mode, email, password) {
  const { firebaseApiKey } = await getConfig()
  if (!firebaseApiKey) {
    throw new Error('Firebase API key is not configured for the extension.')
  }

  const endpoint =
    mode === 'signup'
      ? 'https://identitytoolkit.googleapis.com/v1/accounts:signUp'
      : 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'

  const response = await fetch(`${endpoint}?key=${encodeURIComponent(firebaseApiKey)}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  })

  const json = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new Error(json.error?.message || 'Unable to sign in.')
  }

  const session = {
    email: json.email,
    idToken: json.idToken,
    refreshToken: json.refreshToken,
    expiresAt: Date.now() + Number(json.expiresIn || 3600) * 1000,
  }
  await setStoredSession(session)
  return session
}

async function request(path, init = {}, idToken) {
  const { apiBaseUrl } = await getConfig()
  const headers = new Headers(init.headers)
  headers.set('Content-Type', 'application/json')
  if (idToken) {
    headers.set('Authorization', `Bearer ${idToken}`)
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers,
  })
  const json = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new Error(json.error || 'NexAlgo request failed.')
  }
  return json
}

async function lookupProblem(payload) {
  const json = await request('/problems/lookup', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
  return json.problem ?? null
}

async function submitProblem(payload) {
  if (!payload?.title || !payload?.normalizedUrl || !payload?.problemStatement) {
    throw new Error('Wait for the problem page to finish loading, then press Refresh.')
  }

  const session = await refreshSession(await getStoredSession())
  if (!session?.idToken) {
    throw new Error('Sign in before requesting a NexAlgo review.')
  }

  const json = await request(
    '/submissions',
    {
      method: 'POST',
      body: JSON.stringify({ problem: payload }),
    },
    session.idToken,
  )

  state.latestSubmission = json.submission ?? null
  if (json.existingProblem) {
    state.latestLookup = json.existingProblem
    state.latestMessage = 'This problem is already published in NexAlgo.'
  } else {
    state.latestMessage =
      'Review request submitted. OpenAI generated the draft and it is waiting for admin/editor approval.'
  }
  return json
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'NEXALGO_PAGE_PAYLOAD') {
    state.latestPayload = message.payload
    state.latestError = ''
    state.latestMessage = ''
    lookupProblem(message.payload)
      .then((problem) => {
        state.latestLookup = problem
        sendResponse({ ok: true, problem })
      })
      .catch((error) => {
        state.latestLookup = null
        state.latestError = error instanceof Error ? error.message : 'Unable to reach NexAlgo.'
        sendResponse({ ok: false, error: state.latestError })
      })

    return true
  }

  if (message.type === 'NEXALGO_SIDEPANEL_STATE') {
    Promise.all([getConfig(), getStoredSession()]).then(([config, session]) => {
      sendResponse({
        payload: state.latestPayload,
        problem: state.latestLookup,
        error: state.latestError,
        message: state.latestMessage,
        submission: state.latestSubmission,
        session,
        config,
      })
    })
    return true
  }

  if (message.type === 'NEXALGO_AUTH') {
    firebaseAuth(message.mode, message.email, message.password)
      .then((session) => sendResponse({ ok: true, session }))
      .catch((error) =>
        sendResponse({
          ok: false,
          error: error instanceof Error ? error.message : 'Authentication failed.',
        }),
      )
    return true
  }

  if (message.type === 'NEXALGO_SIGN_OUT') {
    setStoredSession(null).then(() => sendResponse({ ok: true }))
    return true
  }

  if (message.type === 'NEXALGO_SUBMIT_PROBLEM') {
    submitProblem(state.latestPayload)
      .then((result) => sendResponse({ ok: true, result, message: state.latestMessage }))
      .catch((error) =>
        sendResponse({
          ok: false,
          error: error instanceof Error ? error.message : 'Unable to request review.',
        }),
      )
    return true
  }

  if (message.type === 'NEXALGO_OPEN_WEB') {
    getConfig().then(({ webBaseUrl }) => {
      const url = new URL(webBaseUrl)
      if (state.latestPayload?.normalizedUrl) {
        url.searchParams.set('sourceUrl', state.latestPayload.normalizedUrl)
      }
      chrome.tabs.create({ url: url.toString() })
      sendResponse({ ok: true })
    })
    return true
  }

  return false
})
