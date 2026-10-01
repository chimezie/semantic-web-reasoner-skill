import path from "path"
import fs from "fs"
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Export details about named ontology entities as a table",
  args: {
    owlFile: tool.schema.string().optional().describe("The path to the OWL file"),
    reportFile: tool.schema.string().describe("A file where to write report output")
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
                      'export',
                      '--export', reportPath ?? '',
                      '--input', owlPath ?? '',
                      '--header', "IRI|ID|LABEL|SubClass Of|SubClasses|Equivalent Class|SubProperty Of|Type",
                      '--include', "classes properties",
                      '--entity-select', "NAMED"]
    try {
      await Bun.$`${commands}`
    } catch (e: any) {
      return `ontology-report failed: ${e.message || e}${e.stderr ? '\nstderr: ' + e.stderr.toString() : ''}`
    }

    try {
      const raw = fs.readFileSync(reportPath!, "utf-8")
      const allLines = raw.split("\n")
      const total = allLines.length
      if (total <= 200) {
        return raw.trim()
      }
      const truncated = allLines.slice(0, 200).join("\n")
      return `${truncated}\n... (${total} total rows)`
    } catch {
      return `ontology-report: report written to ${reportPath}, but failed to read output.`
    }
  }
})
