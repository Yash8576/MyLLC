function render(problem, payload) {
  const status = document.getElementById('status')
  const content = document.getElementById('content')

  if (!payload) {
    status.textContent = 'Open a LeetCode or GeeksforGeeks problem to begin.'
    content.innerHTML = ''
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
  `
}

chrome.runtime.sendMessage({ type: 'NEXALGO_SIDEPANEL_STATE' }, (response) => {
  render(response?.problem, response?.payload)
})
