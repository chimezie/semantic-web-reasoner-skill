import path from "path"
import fs from "fs"
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "'Compute a number of metrics about your ontology, such as entity and axiom counts, qualitative " +
       "information such as OWL 2 profiles and more complex metrics'",
  args: {
    owlFile: tool.schema.string().optional().describe("The path to the OWL file"),
    reportFile: tool.schema.string().describe("A file where to write JSON report")
  },
  async execute(args, context) {
    const resolvePath = (p: string | undefined): string | undefined => {
      if (!p) return p
      const baseDir = context?.worktree || process.cwd()
      return path.isAbsolute(p) ? p : path.resolve(baseDir, p)
    }

    const owlPath = resolvePath(args.owlFile)
    const reportPath = resolvePath(args.reportFile)

    const commands = ['robot',
                      'measure',
                      '--format', 'json',
                      '--metrics', 'essential',
                      '--output', reportPath ?? '',
                      '--input', owlPath ?? '']
    try {
      await Bun.$`${commands}`
    } catch (e: any) {
      return `ontology-measure-essentials failed: ${e.message || e}${e.stderr ? '\nstderr: ' + e.stderr.toString() : ''}`
    }

    try {
      const raw = fs.readFileSync(reportPath!, "utf-8")
      const data = JSON.parse(raw)

      const lines: string[] = []
      lines.push(`owl2: ${data.owl2 ?? "N/A"}`)
      lines.push(`owl2_dl: ${data.owl2_dl ?? "N/A"}`)
      lines.push(`class_count: ${data.class_count ?? "N/A"}`)
      lines.push(`axiom_count: ${data.axiom_count ?? "N/A"}`)
      lines.push(`owl2dl_profile_violation: ${data.owl2dl_profile_violation ?? "N/A"}`)

      if ((data.owl2dl_profile_violation ?? 0) > 0) {
        const profileCmd = ['robot', 'validate-profile', '--profile', 'DL', '--input', owlPath ?? '']
        try {
          const profileOut = (await Bun.$`${profileCmd}`.text()).trim()
          if (profileOut) {
            lines.push("")
            lines.push("Profile violations (offending entities):")
            lines.push(profileOut)
            lines.push("")
            lines.push("Note: violations may originate in imported ontologies.")
          }
        } catch {
          lines.push("")
          lines.push("Note: could not run robot validate-profile for DL attribution. Profile violations may originate in imported ontologies.")
        }
      }

      return lines.join("\n")
    } catch {
      return `ontology-measure-essentials: report written to ${reportPath}, but failed to parse JSON summary.`
    }
  }
})
