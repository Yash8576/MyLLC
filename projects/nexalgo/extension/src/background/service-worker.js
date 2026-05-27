const state = {
  latestPayload: null,
  latestLookup: null,
}

async function lookupProblem(payload) {
  const storedConfig = await chrome.storage.local.get('NEXALGO_API_BASE_URL')
  const apiBaseUrl = storedConfig.NEXALGO_API_BASE_URL || 'http://localhost:8080/v1'
  const response = await fetch(`${apiBaseUrl}/problems/lookup`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  })

  if (!response.ok) {
    return null
  }

  const json = await response.json()
  return json.problem ?? null
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'NEXALGO_PAGE_PAYLOAD') {
    state.latestPayload = message.payload
    lookupProblem(message.payload)
      .then((problem) => {
        state.latestLookup = problem
        sendResponse({ ok: true, problem })
      })
      .catch(() => {
        sendResponse({ ok: false })
      })

    return true
  }

  if (message.type === 'NEXALGO_SIDEPANEL_STATE') {
    sendResponse({
      payload: state.latestPayload,
      problem: state.latestLookup,
    })
  }

  return false
})
