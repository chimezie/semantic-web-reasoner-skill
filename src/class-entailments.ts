import { tool } from "@opencode-ai/plugin"
import { which } from "bun"
import { resolveConfig } from "./lib/auto-config.js"

export default tool({
  description: "Print logical entailment explanations about class via ELK reasoner with " +
                "`owl_dsl.reason --action explain_logical_inferences` (OWL-DSL).  If used with `byId` argument, then " +
                "`classReference` is the local name " +
                "(the part after the ontology Namespace Base URI or `ontologyNamespaceBaseuri`) " +
                "otherwise it is the rdfs:label",
  args: {
    ontologyUri: tool.schema.string().describe(
        "Ontology URI (must match the base IRI used when loading, including # if present)"),
    sqliteFile: tool.schema.string().describe("Path to SQLite file with pre-loaded ontology (for owlready2 reasoner backend)"),
    baseuri: tool.schema.string().describe(
        "Ontology namespace base URI (used to resolve local names)"),
    classReference: tool.schema.string().describe("Class local name or rdfs:label"),
    byId: tool.schema.boolean().optional().describe("Treat classReference as local name (not label)"),
    owlFile: tool.schema.string().describe("Path to OWL file (passed as positional arg)"),
    configurationFile: tool.schema.string().optional().describe(
        "Optional YAML configuration for NL rendering. Auto-discovered as <stem>.cnl.yaml next to the OWL file. When both YAML and ontology OWL_DSL_* annotations are present, templates and ignore lists accumulate from both; expert_definition_properties from OWL_DSL_000005 take precedence."),
  },
  async execute(args, context) {
    const config = resolveConfig(args.owlFile, args.configurationFile, context?.worktree)
    const command = ['owl_dsl.reason',
                      '--action', 'explain_logical_inferences',
                      '--ontology-uri', args.ontologyUri,
                      '--sqlite-file', args.sqliteFile,
                      '--ontology-namespace-baseuri', args.baseuri,
                      '--class-reference', args.classReference]
    if (config.path) {
      command.push('--configuration-file', config.path)
    }
    if (args.byId) {
      command.push('--by-id')
    }
    command.push(args.owlFile)

    const useUv = which("uv")
    const commands = useUv
      ? ["uv", "run", "--active", ...command]
      : [...command]
    try {
      let result = (await Bun.$`${commands}`.text()).trim()
      if (config.discovered) {
        result = `Using supplementary CNL config: ${config.path}\n${result}`
      }
      return result
    } catch (e: any) {
      return `class-entailments failed: ${e.message || e}${e.stderr ? '\nstderr: ' + e.stderr.toString() : ''}`
    }
  },
})
