import { tool } from "@opencode-ai/plugin"
import { which } from "bun"
import { resolveConfig } from "./lib/auto-config.js"

export default tool({
  description: "Verbalize an OWL class into Controlled Natural Language (CNL) using `owl_dsl.review -a render_class`",
  args: {
    ontologyUri: tool.schema.string().describe("Ontology URI (must match the base IRI used when loading, including # if present)"),
    baseuri: tool.schema.string().describe("Ontology namespace base URI (used to resolve local names)"),
    classReference: tool.schema.string().describe("Class local name or rdfs:label"),
    byId: tool.schema.boolean().optional().describe("Treat classReference as local name (not label)"),
    owlFile: tool.schema.string().describe("Path to the OWL file to verbalize from"),
    configurationFile: tool.schema.string().optional().describe(
        "Optional YAML configuration for NL rendering. Auto-discovered as <stem>.cnl.yaml next to the OWL file. When both YAML and ontology OWL_DSL_* annotations are present, templates and ignore lists accumulate from both; expert_definition_properties from OWL_DSL_000005 take precedence."),
    collectDefinitionInfo: tool.schema.boolean().optional().describe(
        "Collect definition info during rendering (default: on). Maps to --collect-definition-info / --no-collect-definition-info. Omit to use CLI default."),
    fullDefinition: tool.schema.boolean().optional().describe(
        "Include logical CNL in the class summary (default: on). Maps to --full-definition / --no-full-definition. Omit to use CLI default."),
    noTextualDefinition: tool.schema.boolean().optional().describe(
        "Suppress the textual definition, show only logical CNL. Maps to --no-textual-definition (CLI default off). Only pass when true."),
  },
  async execute(args, context) {
    const config = resolveConfig(args.owlFile, args.configurationFile, context?.worktree)
    const command = [
      'owl_dsl.review',
      '-a',
      'render_class',
      '--ontology-uri',
      args.ontologyUri,
      '--ontology-namespace-baseuri',
      args.baseuri,
      '--class-reference',
      args.classReference,
    ]
    if (args.byId) {
      command.push('--by-id')
    }
    if (config.path) {
      command.push('--configuration-file', config.path)
    }
    if (args.collectDefinitionInfo === true) {
      command.push('--collect-definition-info')
    } else if (args.collectDefinitionInfo === false) {
      command.push('--no-collect-definition-info')
    }
    if (args.fullDefinition === true) {
      command.push('--full-definition')
    } else if (args.fullDefinition === false) {
      command.push('--no-full-definition')
    }
    if (args.noTextualDefinition) {
      command.push('--no-textual-definition')
    }
    command.push(args.owlFile)
    const useUv = which("uv")
    const runner = useUv
      ? ["uv", "run", "--active", ...command]
      : [...command]
    try {
      let result = (await Bun.$`${runner}`.text()).trim()

      const isEmptyRender = !result || result === 'Loaded ontology' || /^Loaded ontology\s*$/.test(result)
      if (isEmptyRender) {
        const msg = `verbalize-ontology-class: no CNL rendered for "${args.classReference}" in ${args.owlFile}. The class may not exist, has no definition annotation, or needs a CNL template — pass configurationFile or add OWL_DSL annotations (OWL_DSL_000001–000007).`
        return config.discovered ? `Using supplementary CNL config: ${config.path}\n${msg}` : msg
      }

      if (config.discovered) {
        result = `Using supplementary CNL config: ${config.path}\n${result}`
      }
      return result
    } catch (e: any) {
      return `verbalize-ontology-class failed: ${e.message || e}${e.stderr ? '\nstderr: ' + e.stderr.toString() : ''}`
    }
  },
})
