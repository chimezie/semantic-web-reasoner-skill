import { join, dirname, basename } from "path"
import { existsSync } from "fs"

// Explicit YAML fallback resolver.
// Returning { discovered: false } with no path is valid — upstream
// resolve_definition_properties will then use ontology-embedded OWL_DSL_* annotations.
export function resolveConfig(
  owlFile: string,
  explicit: string | undefined,
  worktree?: string,
): { path?: string; discovered: boolean } {
  if (explicit) {
    const resolved = worktree ? join(worktree, explicit) : explicit
    return { path: resolved, discovered: false }
  }

  const owlDir = dirname(owlFile)
  const stem = basename(owlFile, ".owl")
  const candidates = [
    join(owlDir, `${stem}.cnl.yaml`),
    join(owlDir, `${stem}.CNL.yaml`),
    join(owlDir, `${stem}.cnl.yml`),
  ]

  for (const candidate of candidates) {
    if (existsSync(candidate)) {
      return { path: candidate, discovered: true }
    }
  }

  return { discovered: false }
}
