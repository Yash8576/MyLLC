const state = {
  payload: null,
  problem: null,
  submission: null,
  session: null,
  error: '',
  message: '',
  config: null,
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

function difficultyClass(difficulty) {
  const normalized = String(difficulty ?? '').toLowerCase()
  if (normalized.includes('easy')) return 'easy'
  if (normalized.includes('medium')) return 'medium'
  if (normalized.includes('hard')) return 'hard'
  return ''
}

function listItems(items) {
  if (!items?.length) return '<p class="muted">None yet.</p>'
  return `<div class="chips">${items.map((item) => `<span>${escapeHtml(item)}</span>`).join('')}</div>`
}

function solutionTabs(solutions = {}) {
  const entries = [
    ['python', 'Python'],
    ['java', 'Java'],
    ['cpp', 'C++'],
  ].filter(([key]) => solutions[key])

  if (entries.length === 0) {
    return '<p class="muted">Solutions will appear after editorial approval.</p>'
  }

  return entries
    .map(
      ([key, label]) => `
        <details class="code-panel" ${key === entries[0][0] ? 'open' : ''}>
          <summary>${label}</summary>
          <pre>${escapeHtml(solutions[key])}</pre>
        </details>
      `,
    )
    .join('')
}

function renderAuth() {
  const auth = document.getElementById('auth')
  if (!auth) return

  if (state.session?.email) {
    auth.innerHTML = `
      <div class="auth-row">
        <span>Signed in as <strong>${escapeHtml(state.session.email)}</strong></span>
        <button type="button" class="ghost small" id="sign-out">Sign out</button>
      </div>
    `
    document.getElementById('sign-out')?.addEventListener('click', signOut)
    return
  }

  auth.innerHTML = `
    <form id="auth-form" class="auth-form">
      <input id="auth-email" type="email" autocomplete="email" placeholder="Email" required />
      <input id="auth-password" type="password" autocomplete="current-password" placeholder="Password" required />
      <div class="button-row">
        <button type="submit" data-mode="login">Sign in</button>
        <button type="submit" class="secondary" data-mode="signup">Create account</button>
      </div>
    </form>
  `

  document.querySelectorAll('#auth-form button[type="submit"]').forEach((button) => {
    button.addEventListener('click', () => {
      document.getElementById('auth-form')?.setAttribute('data-mode', button.dataset.mode || 'login')
    })
  })
  document.getElementById('auth-form')?.addEventListener('submit', authenticate)
}

function renderProblem(problem) {
  const title = problem.problemNumber ? `${problem.problemNumber}. ${problem.title}` : problem.title
  const difficulty = problem.difficulty || 'Difficulty pending'

  return `
    <section class="hero published">
      <span class="eyebrow">Published in NexAlgo</span>
      <h2>${escapeHtml(title)}</h2>
      <span class="difficulty ${difficultyClass(difficulty)}">${escapeHtml(difficulty)}</span>
    </section>

    <section>
      <h3>Problem</h3>
      <p>${escapeHtml(problem.problemStatement)}</p>
    </section>

    <section>
      <h3>Hints</h3>
      ${
        problem.hints?.length
          ? `<ol>${problem.hints.map((hint) => `<li>${escapeHtml(hint)}</li>`).join('')}</ol>`
          : '<p class="muted">No hints yet.</p>'
      }
    </section>

    <section>
      <h3>Topics</h3>
      ${listItems(problem.topics)}
    </section>

    <section>
      <h3>Companies</h3>
      ${listItems(problem.companies)}
    </section>

    <section>
      <h3>Intuition</h3>
      <p>${escapeHtml(problem.intuition || 'Editorial intuition pending.')}</p>
    </section>

    <section>
      <h3>Walkthrough</h3>
      <p>${escapeHtml(problem.walkthrough || 'Walkthrough pending.')}</p>
    </section>

    <section>
      <h3>Complexity</h3>
      <p>${escapeHtml(problem.complexityAnalysis || 'Complexity analysis pending.')}</p>
    </section>

    <section>
      <h3>Solutions</h3>
      ${solutionTabs(problem.solutions)}
    </section>
  `
}

function renderMissing(payload) {
  const ready = payload?.title && payload?.normalizedUrl && payload?.problemStatement
  const pending = state.submission

  return `
    <section class="hero missing">
      <span class="eyebrow">Not in NexAlgo yet</span>
      <h2>${escapeHtml(payload?.title || 'Supported problem page detected')}</h2>
      <p>Request a review to generate a draft with OpenAI and send it to the admin/editor queue.</p>
    </section>

    ${pending ? '<p class="message">Submitted. Waiting for admin/editor approval before it appears in the library.</p>' : ''}
    ${state.message ? `<p class="message">${escapeHtml(state.message)}</p>` : ''}

    <section>
      <h3>Captured Details</h3>
      <dl>
        <dt>Platform</dt>
        <dd>${escapeHtml(payload?.platform || 'Unknown')}</dd>
        <dt>Difficulty</dt>
        <dd>${escapeHtml(payload?.difficulty || 'Unknown')}</dd>
        <dt>URL</dt>
        <dd class="break">${escapeHtml(payload?.normalizedUrl || '')}</dd>
      </dl>
    </section>

    <section>
      <h3>Statement Preview</h3>
      <p>${escapeHtml(payload?.problemStatement || 'The extension is still waiting for the page content to load. Press Refresh after the problem statement appears.')}</p>
    </section>

    <button type="button" id="submit-review" ${ready || pending ? '' : 'disabled'}>
      ${pending ? 'Review requested' : 'Request NexAlgo review'}
    </button>
  `
}

function renderEmpty() {
  return `
    <section class="hero idle">
      <span class="eyebrow">Waiting for a problem</span>
      <h2>Open LeetCode or GeeksforGeeks</h2>
      <p>The side panel will show published NexAlgo details or a review request flow for missing problems.</p>
    </section>
  `
}

function render() {
  const status = document.getElementById('status')
  const content = document.getElementById('content')
  if (!status || !content) return

  renderAuth()

  if (state.error) {
    status.textContent = 'NexAlgo needs attention.'
    content.innerHTML = `<p class="error">${escapeHtml(state.error)}</p>${state.payload ? renderMissing(state.payload) : renderEmpty()}`
  } else if (state.problem) {
    status.textContent = 'Published problem loaded.'
    content.innerHTML = renderProblem(state.problem)
  } else if (state.payload) {
    status.textContent = 'Problem captured from this page.'
    content.innerHTML = renderMissing(state.payload)
  } else {
    status.textContent = 'Waiting for a supported problem page.'
    content.innerHTML = renderEmpty()
  }

  document.getElementById('submit-review')?.addEventListener('click', submitReview)
}

function refresh() {
  chrome.runtime.sendMessage({ type: 'NEXALGO_SIDEPANEL_STATE' }, (response) => {
    if (chrome.runtime.lastError) {
      state.error = chrome.runtime.lastError.message
      render()
      return
    }

    Object.assign(state, {
      payload: response?.payload ?? null,
      problem: response?.problem ?? null,
      submission: response?.submission ?? null,
      session: response?.session ?? null,
      error: response?.error ?? '',
      message: response?.message ?? '',
      config: response?.config ?? null,
    })
    render()
  })
}

function authenticate(event) {
  event.preventDefault()
  const form = event.currentTarget
  const mode = form.getAttribute('data-mode') || 'login'
  const email = document.getElementById('auth-email')?.value?.trim()
  const password = document.getElementById('auth-password')?.value

  chrome.runtime.sendMessage({ type: 'NEXALGO_AUTH', mode, email, password }, (response) => {
    if (!response?.ok) {
      state.error = response?.error || 'Authentication failed.'
    }
    refresh()
  })
}

function signOut() {
  chrome.runtime.sendMessage({ type: 'NEXALGO_SIGN_OUT' }, () => refresh())
}

function submitReview() {
  state.error = ''
  state.message = 'Generating draft and submitting review request...'
  render()
  chrome.runtime.sendMessage({ type: 'NEXALGO_SUBMIT_PROBLEM' }, (response) => {
    if (!response?.ok) {
      state.error = response?.error || 'Unable to submit review request.'
    } else {
      state.message = response.message || 'Review request submitted.'
    }
    refresh()
  })
}

document.getElementById('refresh')?.addEventListener('click', refresh)
document.getElementById('open-web')?.addEventListener('click', () => {
  chrome.runtime.sendMessage({ type: 'NEXALGO_OPEN_WEB' }, () => {
    void chrome.runtime.lastError
  })
})

refresh()
