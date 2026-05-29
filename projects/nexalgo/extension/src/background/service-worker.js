import '../config.js'

const state = {
  latestPayload: null,
  latestLookup: null,
  latestError: '',
}

chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch(() => {
  // Chrome may reject this during transient service worker startup states.
})

async function getConfig() {
  const defaults = globalThis.NEXALGO_EXTENSION_CONFIG

  return {
    apiBaseUrl: defaults.apiBaseUrl.replace(/\/+$/, ''),
    webBaseUrl: defaults.webBaseUrl.replace(/\/+$/, ''),
  }
}

async function lookupProblem(payload) {
  const { apiBaseUrl } = await getConfig()
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
    state.latestError = ''
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
    getConfig().then((config) => {
      sendResponse({
        payload: state.latestPayload,
        problem: state.latestLookup,
        error: state.latestError,
        config,
      })
    })
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
