import path from "path"
import os from "os"
import { tool } from "@opencode-ai/plugin"
import { which } from "bun"

const TOOLS_DIR = path.join(os.homedir(), ".opencode", "tools")

export default tool({
  description: "Create OWL_DSL / owlready2 SQLite ontology and archive provenance for later use by " +
       "class-entailments (the ELK reasoner). Note: review tools (verbalize-ontology-class, find-ontology-class, " +
       "find-ontology-property) read the OWL file directly via pyhornedowl and do NOT need this step." +
       " Uses create-ontology.py",
  args: {
    ontologyUri: tool.schema.string().describe(
        "Ontology URI (must match the base IRI used when loading, including # if present)"),
    baseuri: tool.schema.string().describe(
        "Ontology namespace base URI (used to resolve local names)"),
    owlFile: tool.schema.string().describe(
        "The path to the OWL file to load into the SQL file for use with owlready 2"),
    workingDir: tool.schema.string().optional().describe(
        "The working directory where ontology SQLite files and archives will be kept. Defaults to the directory containing the OWL file."),
  },
  async execute(args, context) {
    const script = path.join(TOOLS_DIR, "create-ontology.py")

    const resolvePath = (p: string | undefined): string | undefined => {
      if (!p) return p
      const baseDir = context?.worktree || process.cwd()
      return path.isAbsolute(p) ? p : path.resolve(baseDir, p)
    }

    const owlPath = resolvePath(args.owlFile)
    const defaultWorkingDir = owlPath ? path.dirname(owlPath) : "/tmp"
    const working_dir = args.workingDir ? args.workingDir : defaultWorkingDir

    const useUv = which("uv")
    const commands = useUv
      ? ["uv", "run", "--active", script,
          String(args.ontologyUri),
          String(args.baseuri),
          String(owlPath ?? args.owlFile), working_dir]
      : ["python3", script,
          String(args.ontologyUri),
          String(args.baseuri),
          String(owlPath ?? args.owlFile), working_dir]
    try {
      const result = await Bun.$`${commands}`.text()
      return result.trim()
    } catch (e: any) {
      return `create-ontology failed: ${e.message || e}${e.stderr ? '\nstderr: ' + e.stderr.toString() : ''}`
    }
  },
})
