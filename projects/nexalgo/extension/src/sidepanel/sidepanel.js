function render(problem, payload, error, config) {
  const status = document.getElementById('status')
  const content = document.getElementById('content')

  if (!payload) {
    status.textContent = 'Open a LeetCode or GeeksforGeeks problem to begin.'
    content.innerHTML = `<p class="muted">API: ${config?.apiBaseUrl ?? 'not configured'}</p>`
    return
  }

  if (error) {
    status.textContent = 'NexAlgo backend is not reachable.'
    content.innerHTML = `
      <p class="error">${error}</p>
      <pre>${JSON.stringify(payload, null, 2)}</pre>
    `
    return
  }

  if (problem) {
    status.textContent = `${problem.title} is already available in NexAlgo.`
    content.innerHTML = `
      <p><strong>${problem.title}</strong></p>
      <p>${problem.problemStatement ?? ''}</p>
    `
    return
  }

  status.textContent = 'This problem is not in NexAlgo yet.'
  content.innerHTML = `
    <p><strong>${payload.title}</strong></p>
    <p>Users will be able to submit this problem into the NexAlgo review queue.</p>
    <pre>${JSON.stringify(payload, null, 2)}</pre>
  `
}

function refresh() {
  chrome.runtime.sendMessage({ type: 'NEXALGO_SIDEPANEL_STATE' }, (response) => {
    if (chrome.runtime.lastError) {
      render(null, null, chrome.runtime.lastError.message, null)
      return
    }
    render(response?.problem, response?.payload, response?.error, response?.config)
  })
}

document.getElementById('refresh')?.addEventListener('click', refresh)
document.getElementById('open-web')?.addEventListener('click', () => {
  chrome.runtime.sendMessage({ type: 'NEXALGO_OPEN_WEB' }, () => {
    void chrome.runtime.lastError
  })
})

refresh()
