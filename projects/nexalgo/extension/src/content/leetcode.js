(function bootstrapLeetCodeScraper() {
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
    const titleMatch = canonicalUrl.match(/\/problems\/([^/]+)/)
    const title =
      readText('[data-track-load="description_content"] h1') ||
      readText('div.text-title-large') ||
      document.title.replace(' - LeetCode', '')

    return {
      platform: 'leetcode',
      slug: titleMatch?.[1],
      normalizedUrl: canonicalUrl,
      title,
      problemStatement:
        readText('[data-track-load="description_content"]') ||
        readText('.elfjS') ||
        '',
      difficulty:
        readText('[diff]') ||
        readAllTexts('div.text-difficulty-easy, div.text-difficulty-medium, div.text-difficulty-hard')[0] ||
        '',
      topics: readAllTexts('[class*="topic-tag"], a[href*="/tag/"]'),
      companies: readAllTexts('[class*="company"], button[class*="company"]'),
    }
  }

  chrome.runtime.sendMessage({
    type: 'NEXALGO_PAGE_PAYLOAD',
    payload: buildPayload(),
  }, () => {
    void chrome.runtime.lastError
  })
})()
