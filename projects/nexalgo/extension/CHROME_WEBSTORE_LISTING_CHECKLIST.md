# Chrome Web Store Publish Checklist

Use these answers in the Chrome Web Store Developer Dashboard.

## Privacy Practices

Single purpose:

```text
NexAlgo helps users identify coding problems on supported practice websites and check whether those problems already exist in the NexAlgo library.
```

Host permission justification:

```text
The extension runs only on LeetCode and GeeksforGeeks problem pages to read the currently visible problem title, URL, difficulty, topics, companies, and problem statement. It also contacts the NexAlgo backend API to check whether the problem already exists in the NexAlgo library.
```

sidePanel justification:

```text
The side panel displays the detected coding problem and the matching NexAlgo result without navigating away from the problem page.
```

Remote code justification:

```text
The extension does not execute remote code. It only sends JSON requests to the NexAlgo backend API and renders JSON responses using JavaScript packaged inside the extension.
```

Data usage certification:

```text
Certify that data usage complies with the Chrome Web Store Developer Program Policies.
```

## Data Disclosure

If the form asks what user data is collected, select website content or page content only if required by the exact form wording. The extension reads problem page content and URL from supported coding websites and sends that problem metadata to the NexAlgo backend for lookup.

Suggested explanation:

```text
The extension reads coding problem metadata from supported problem pages, including page URL, title, problem statement, difficulty, topics, and companies. This data is sent to the NexAlgo backend only to check for a matching problem in the NexAlgo library.
```

## Store Listing

You must upload at least one screenshot or video before publishing.

Suggested screenshots:

```text
1. LeetCode problem page with the NexAlgo side panel open.
2. NexAlgo side panel showing an existing problem match or "not in NexAlgo yet".
```

## Account Settings

Before publishing:

```text
1. Add the publisher contact email in the Chrome Web Store Developer Dashboard settings.
2. Complete the email verification process.
3. Save Draft after every completed tab.
```
