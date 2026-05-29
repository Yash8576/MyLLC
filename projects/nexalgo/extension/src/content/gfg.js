(function bootstrapGfgScraper() {
  function readText(selector) {
    return document.querySelector(selector)?.textContent?.trim() || ''
  }

  function readAllTexts(selector) {
    return Array.from(document.querySelectorAll(selector))
      .map((node) => node.textContent?.trim())
      .filter(Boolean)
  }

  function buildPayload() {
    const canonicalUrl =
      document.querySelector('link[rel="canonical"]')?.href || window.location.href
    const slugMatch = canonicalUrl.match(/\/problems\/([^/?]+)/)

    return {
      platform: 'gfg',
      slug: slugMatch?.[1],
      normalizedUrl: canonicalUrl,
      title:
        readText('h1') ||
        document.title.replace(' - GeeksforGeeks', ''),
      problemStatement:
        readText('.problems_problem_content__Xm_eO') ||
        readText('.problem-statement') ||
        '',
      difficulty: readText('[class*="difficulty"]'),
      topics: readAllTexts('[class*="tag"], [class*="Topic"] button'),
      companies: readAllTexts('[class*="company"] button, [class*="Company"] button'),
    }
  }

  function sendPayload() {
    chrome.runtime.sendMessage({
      type: 'NEXALGO_PAGE_PAYLOAD',
      payload: buildPayload(),
    }, () => {
      void chrome.runtime.lastError
    })
  }

  sendPayload()
  window.setTimeout(sendPayload, 1500)
  window.setTimeout(sendPayload, 4000)
})()
