import { tool } from "@opencode-ai/plugin"
import { which } from "bun"
import { resolveConfig } from "./lib/auto-config.js"

export default tool({
  description: "Find OWL properties by label pattern using `owl_dsl.review`",
  args: {
    ontologyUri: tool.schema.string().describe("Ontology URI (must match the base IRI used when loading, including # if present)"),
    baseuri: tool.schema.string().optional().describe("Ontology namespace base URI (defaults to ontologyUri)"),
    prefix: tool.schema.string().optional().describe("URI prefix filter"),
    propReferenceLabel: tool.schema.string().optional().describe("Property label regex filter"),
    limit: tool.schema.number().optional().describe("Max results (default 10)"),
    showPropertyDefinitionUsage: tool.schema.boolean().optional().describe("Show property definition usage (default false)"),
    owlFile: tool.schema.string().describe("The path to the OWL file"),
    configurationFile: tool.schema.string().optional().describe(
        "Optional YAML configuration for NL rendering. Auto-discovered as <stem>.cnl.yaml next to the OWL file. When both YAML and ontology OWL_DSL_* annotations are present, templates and ignore lists accumulate from both; expert_definition_properties from OWL_DSL_000005 take precedence.")
  },
  async execute(args, context) {
    const config = resolveConfig(args.owlFile, args.configurationFile, context?.worktree)
    const command = ['owl_dsl.review',
                      '-a', 'find_properties',
                      '--ontology-uri', args.ontologyUri,
                      '--ontology-namespace-baseuri', args.baseuri ?? args.ontologyUri]
    if (args.prefix) {
      command.push('--prefix', args.prefix)
    }
    if (args.propReferenceLabel) {
      command.push('--prop-reference-label', args.propReferenceLabel)
    }
    if (config.path) {
      command.push('--configuration-file', config.path)
    }
    command.push('--limit', String(args.limit ?? 10))
    if (args.showPropertyDefinitionUsage) {
      command.push('--show-property-definition-usage')
    }
    command.push(args.owlFile)

    const useUv = which("uv")
    const commands = useUv
      ? ["uv", "run", "--active", ...command]
      : [...command]
    try {
      return (await Bun.$`${commands}`.text()).trim()
    } catch (e: any) {
      return `find-ontology-property failed: ${e.message || e}${e.stderr ? '\nstderr: ' + e.stderr.toString() : ''}`
    }
  }
})
