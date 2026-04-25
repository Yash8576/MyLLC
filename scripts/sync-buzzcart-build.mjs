import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs'
import path from 'node:path'

const repoRoot = process.cwd()
const sourceDir = path.join(repoRoot, 'projects', 'buzzcart', 'frontend', 'build', 'web')
const targetDir = path.join(repoRoot, 'public', 'nexacore', 'BuzzCart')

if (!existsSync(sourceDir)) {
  console.error(`BuzzCart web build not found at ${sourceDir}`)
  process.exit(1)
}

rmSync(targetDir, { recursive: true, force: true })
mkdirSync(targetDir, { recursive: true })
cpSync(sourceDir, targetDir, { recursive: true })

const entryPoints = ['Login', 'Signup']
for (const entryPoint of entryPoints) {
  const entryDir = path.join(targetDir, entryPoint)
  mkdirSync(entryDir, { recursive: true })
  cpSync(path.join(sourceDir, 'index.html'), path.join(entryDir, 'index.html'))
}

console.log(`Synced BuzzCart web build to ${targetDir}`)
