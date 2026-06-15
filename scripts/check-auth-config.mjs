import { initializeApp, cert } from 'firebase-admin/app'
import { readFileSync } from 'fs'

const sa = JSON.parse(readFileSync('C:\\Users\\dravi\\Downloads\\Resumes\\buzz-to-do-ce31a1baa65d.json', 'utf8'))
initializeApp({ credential: cert(sa) })

// Check which auth providers are enabled via Identity Toolkit API
import { createSign } from 'crypto'

const now = Math.floor(Date.now() / 1000)
const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT', kid: sa.private_key_id })).toString('base64url')
const payload = Buffer.from(JSON.stringify({
  iss: sa.client_email, sub: sa.client_email,
  aud: 'https://oauth2.googleapis.com/token',
  iat: now, exp: now + 3600,
  scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase',
})).toString('base64url')
const sign = createSign('RSA-SHA256')
sign.update(`${header}.${payload}`)
const jwt = `${header}.${payload}.${sign.sign(sa.private_key, 'base64url')}`

const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
})
const { access_token } = await tokenRes.json()

// Get project config from Identity Toolkit
const res = await fetch(
  `https://identitytoolkit.googleapis.com/admin/v2/projects/buzz-to-do/config`,
  { headers: { Authorization: `Bearer ${access_token}` } }
)
const config = await res.json()
console.log('Auth config:', JSON.stringify(config, null, 2))
