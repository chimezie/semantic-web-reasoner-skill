import { tool } from "@opencode-ai/plugin"
import { which } from "bun"

export default tool({
  description: "Find OWL class by label pattern (string or REGEX) using `owl_dsl.review --action find_classes`",
  args: {
    ontologyUri: tool.schema.string().describe("Ontology URI (must match the base IRI used when loading, including # if present)"),
    classSearch: tool.schema.string().describe("Label pattern to search for (substring or regex)"),
    regexSearch: tool.schema.boolean().optional().describe("Use regex matching instead of substring (default false)"),
    owlFile: tool.schema.string().describe("Path to the OWL file to search"),
  },
  async execute(args, context) {
    const regexFlag = args.regexSearch ? "--regex-search" : "--no-regex-search"
    const command = ['owl_dsl.review',
                            '--action', 'find_classes',
                            '--ontology-uri', args.ontologyUri,
                            '--class-search', args.classSearch,
                            regexFlag,
                            args.owlFile]
    const useUv = which("uv")
    const commands = useUv
      ? ["uv", "run", "--active", ...command]
      : [...command]
    const result = await Bun.$`${commands}`.text()
    return result.trim()
  },
})
