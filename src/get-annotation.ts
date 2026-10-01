import path from "path"
import os from "os"
import { tool } from "@opencode-ai/plugin"
import { which } from "bun"

const TOOLS_DIR = path.join(os.homedir(), ".opencode", "tools")

export default tool({
  description: "Get annotation values on an OWL class",
  args: {
    owlFile: tool.schema.string().describe("The path to the OWL file"),
    baseuri: tool.schema.string().describe(
        "Ontology namespace base URI (used to resolve local names)"),
    classReference: tool.schema.string().describe("Class local name or rdfs:label"),
    byId: tool.schema.boolean().optional().describe("Treat classReference as local name (not label)"),
    annotationProperty: tool.schema.string().describe(
        "Annotation property URI or CURIE (e.g. skos:prefLabel)"),
  },
  async execute(args, context) {
    const script = path.join(TOOLS_DIR, "get-annotation.py")
    const byId = String(!!args.byId)

    const useUv = which("uv")
    const commands = useUv
      ? ["uv", "run", "--active", script,
         String(args.owlFile), String(args.baseuri),
         String(args.classReference), byId, String(args.annotationProperty)]
      : ["python3", script,
         String(args.owlFile), String(args.baseuri),
         String(args.classReference), byId, String(args.annotationProperty)]
    const result = await Bun.$`${commands}`.text()
    return result.trim()
  },
})
