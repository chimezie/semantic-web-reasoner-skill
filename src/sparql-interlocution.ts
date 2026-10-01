import path from "path"
import os from "os"
import { tool } from "@opencode-ai/plugin"
import { which } from "bun"

const TOOLS_DIR = path.join(os.homedir(), ".opencode", "tools")

export default tool({
  description: "Execute a SPARQL queries over a remote endpoint with OWL entailment via FuXi's sparql_interlocution_basic_graph_pattern" +
      " against the specified URL, using any provided prefix to Namespace URI mappings, an OWL Ontology, and rules that" +
      " govern the semantics of the terms in the remote RDF dataset",
  args: {
    sparqlServiceGraph: tool.schema.string().describe("URL of the SPARQL endpoint"),
    nsBindings: tool.schema.string().describe(
        "JSON object mapping prefixes to namespace URIs, e.g. " +
        `'{"rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "rdfs": "http://www.w3.org/2000/01/rdf-schema#"}'`),
    query: tool.schema.string().describe("SPARQL query string"),
    owlFile: tool.schema.string().optional().describe(
        "Path to an OWL file for the TBox (loaded locally for DLP; SPARQL endpoint serves as EDB only)"),
    rulesFile: tool.schema.string().optional().describe(
        "Path to an N3 rules file for custom entailment rules")
  },
  async execute(args, context) {
    const script = path.join(TOOLS_DIR, "sparql-interlocution.py")

    const argsList = [
      String(args.sparqlServiceGraph),
      String(args.nsBindings),
      String(args.query),
      args.owlFile ?? "--",
      args.rulesFile ?? "--",
    ]

    const useUv = which("uv")
    const commands = useUv
      ? ["uv", "run", "--active", script, ...argsList]
      : ["python3", script, ...argsList]
    const result = await Bun.$`${commands}`.text()
    return result.trim()
  },
})
