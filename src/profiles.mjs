import { readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

// Keep in sync with PROFILE_* in deploy.sh — the two tools must not drift.
export const PROFILES = {
  'web-app': [
    'nextjs-core', 'database', 'security', 'typescript', 'react-patterns',
    'ui-engineering', 'error-handling', 'testing', 'api-design', 'email', 'env-config',
  ],
  mobile: ['react-native', 'typescript', 'state-management', 'performance', 'testing'],
  static: ['nextjs-core', 'ui-engineering', 'seo', 'performance', 'typescript', 'accessibility'],
  api: ['api-design', 'database', 'security', 'error-handling', 'typescript', 'email', 'env-config'],
}

export function getAllSkills(libraryDir) {
  const genericDir = join(libraryDir, 'skills', 'generic')
  return readdirSync(genericDir)
    .filter((name) => statSync(join(genericDir, name)).isDirectory())
    .sort()
}

/** Returns the skill list for a profile, or `null` when nothing should be filtered (full). */
export function resolveProfileSkills(profile, customSkills) {
  if (profile === 'full') return null
  if (profile === 'custom') return customSkills ?? []
  const skills = PROFILES[profile]
  if (!skills) {
    throw new Error(`Unknown profile: ${profile}. Use web-app | mobile | static | api | custom | full`)
  }
  return skills
}
