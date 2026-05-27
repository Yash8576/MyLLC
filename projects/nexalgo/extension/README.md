# NexAlgo Chrome Extension

This folder contains the Manifest V3 extension scaffold for NexAlgo.

## Responsibilities

- detect supported coding-problem pages
- normalize page data for LeetCode and GeeksforGeeks
- ask the NexAlgo backend whether the problem already exists
- render the result inside the Chrome side panel
- allow signed-in users to submit missing problems into the NexAlgo review queue

## Expected runtime config

The extension expects the following values to be injected during packaging or build:

- `NEXALGO_API_BASE_URL`
- `NEXALGO_WEB_BASE_URL`
- Firebase web config if extension-side Firebase Auth is enabled

## Notes

- The files here are plain JS/HTML scaffolds so the repo can carry the intended structure now.
- You can later wrap this in Vite, Plasmo, or another extension build pipeline if you want stronger DX.
