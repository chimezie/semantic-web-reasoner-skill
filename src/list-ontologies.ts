import path from "path"
import os from "os"
import { tool } from "@opencode-ai/plugin"
import { which } from "bun"

const TOOLS_DIR = path.join(os.homedir(), ".opencode", "tools")

export default tool({
  description: "List OWL ontologies available via owlready2 SQLite (reasoner path). Reads <workingDir>/ontology_db.json. " +
                "Pass the same workingDir used when calling create-ontology.",
  args: {
    workingDir: tool.schema.string().optional().describe(
        "Working directory containing ontology_db.json. Defaults to /tmp. Pass the same value used with create-ontology."),
  },
  async execute(args, context) {
    const script = path.join(TOOLS_DIR, "list-ontologies.py")

    const useUv = which("uv")
    const working_dir = args.workingDir ? args.workingDir : "/tmp"
    const commands = useUv
      ? ["uv", "run", "--active", script, String(working_dir)]
      : ["python3", script, String(working_dir)]
    try {
      const result = await Bun.$`${commands}`.text()
      return result.trim()
    } catch (e: any) {
      return `list-ontologies failed: ${e.message || e}${e.stderr ? '\nstderr: ' + e.stderr.toString() : ''}`
    }
  },
})
