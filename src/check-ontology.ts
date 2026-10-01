import path from "path"
import fs from "fs"
import os from "os"
import { tool } from "@opencode-ai/plugin"
import { which } from "bun"

const DEFAULT_RULES = [
  { level: "WARN", name: "annotation_whitespace" },
  { level: "ERROR", name: "deprecated_boolean_datatype" },
  { level: "ERROR", name: "deprecated_class_reference" },
  { level: "ERROR", name: "deprecated_property_reference" },
  { level: "ERROR", name: "duplicate_definition" },
  { level: "WARN", name: "duplicate_exact_synonym" },
  { level: "WARN", name: "duplicate_label_synonym" },
  { level: "ERROR", name: "duplicate_label" },
  { level: "WARN", name: "duplicate_scoped_synonym" },
  { level: "WARN", name: "equivalent_pair" },
  { level: "WARN", name: "equivalent_class_axiom_no_genus" },
  { level: "ERROR", name: "illegal_use_of_built_in_vocabulary" },
  { level: "WARN", name: "invalid_xref" },
  { level: "ERROR", name: "label_formatting" },
  { level: "ERROR", name: "label_whitespace" },
  { level: "INFO", name: "lowercase_definition" },
  { level: "WARN", name: "missing_definition" },
  { level: "ERROR", name: "missing_label" },
  { level: "WARN", name: "missing_obsolete_label" },
  { level: "ERROR", name: "missing_ontology_description" },
  { level: "ERROR", name: "missing_ontology_license" },
  { level: "ERROR", name: "missing_ontology_title" },
  { level: "WARN", name: "missing_subset_declaration" },
  { level: "INFO", name: "missing_superclass" },
  { level: "WARN", name: "missing_synonymtype_declaration" },
  { level: "ERROR", name: "misused_obsolete_label" },
  { level: "ERROR", name: "misused_replaced_by" },
  { level: "ERROR", name: "multiple_definitions" },
  { level: "WARN", name: "multiple_equivalent_classes" },
  { level: "ERROR", name: "multiple_equivalent_class_definitions" },
  { level: "ERROR", name: "multiple_labels" },
  { level: "WARN", name: "invalid_entity_uri" },
]

export default tool({
  description: "Run a report on an OWL file for all the issues it has",
  args: {
    owlFile: tool.schema.string().optional().describe("The path to the OWL file"),
    reportFile: tool.schema.string().optional().describe("A file where to write JSON report"),
    imports: tool.schema.boolean().default(false).describe(
        "Load imported ontologies. Auto-detects catalog-v001.xml / catalog-v2.xml / catalog.xml in the OWL file directory — if found and imports is not false, uses the catalog instead of stripping imports. (default: false, strips owl:imports to avoid HTTP failures)"),
    failOn: tool.schema.string().default("NONE").describe(
        "Robot --fail-on level: NONE, ALL, ERROR, WARN, INFO (default: NONE means always succeed)"),
    select: tool.schema.string().optional().describe(
        "Comma-separated rule names to include (e.g. 'missing_definition,missing_label'). Generates a temporary profile."),
    exclude: tool.schema.string().optional().describe(
        "Comma-separated rule names to exclude (e.g. 'duplicate_label'). Generates a temporary profile. Note: excluded rules still count toward --fail-on."),
    profile: tool.schema.string().optional().describe(
        "Path to an existing ROBOT report-profile file (LEVEL<TAB>rule_name format)."),
  },
  async execute(args, context) {
    const useUv = which("uv")
    const robotPath = which("robot")

    const resolvePath = (p: string | undefined): string | undefined => {
      if (!p) return p
      const baseDir = context?.worktree || process.cwd()
      return path.isAbsolute(p) ? p : path.resolve(baseDir, p)
    }

    const owlPath = resolvePath(args.owlFile)
    const catalogCandidates = owlPath
      ? ["catalog-v001.xml", "catalog-v2.xml", "catalog.xml"].map(f => path.join(path.dirname(owlPath), f))
      : []
    const catalogPath = catalogCandidates.find(f => fs.existsSync(f))

    let inputFile = owlPath
    let tempDir: string | null = null
    let tempProfile: string | null = null
    let strippedNote = ""

    if (catalogPath && args.imports !== false) {
      inputFile = owlPath
    } else if (!args.imports && owlPath) {
      const pythonScript = `
import sys, os, tempfile
from rdflib import Graph, Namespace
g = Graph()
g.parse(sys.argv[1], format="xml")
OWL = Namespace("http://www.w3.org/2002/07/owl#")
for s, p, o in list(g.triples((None, OWL.imports, None))):
    g.remove((s, p, o))
outdir = tempfile.mkdtemp()
out = os.path.join(outdir, "stripped.owl")
g.serialize(out, format="xml")
print(outdir)
      `.trim()
      const pythonCmd = useUv
        ? ["uv", "run", "--active", "python", "-c", pythonScript, owlPath]
        : ["python3", "-c", pythonScript, owlPath]
      try {
        const out = (await Bun.$`${pythonCmd}`.text()).trim()
        if (out) {
          tempDir = out
          inputFile = `${out}/stripped.owl`
        }
      } catch (e: any) {
        return `Python stripping failed: ${e.message || e}`
      }
      if (!catalogPath) {
        strippedNote = "NOTE: imports stripped (no catalog found); missing_definition / missing_superclass / duplicate_label for imported terms are expected.\n"
      }
    } else if (args.imports === true) {
      inputFile = owlPath
    }

    if (args.profile) {
      const resolvedProfile = resolvePath(args.profile)
      if (resolvedProfile && fs.existsSync(resolvedProfile)) {
        tempProfile = resolvedProfile
      }
    } else if (args.select || args.exclude) {
      const tmpDir = os.tmpdir()
      const profileFile = path.join(tmpDir, `robot-profile-${Date.now()}.txt`)
      const selected = args.select ? args.select.split(",").map(s => s.trim()).filter(Boolean) : null
      const excluded = args.exclude ? args.exclude.split(",").map(s => s.trim()).filter(Boolean) : null

      let rules = DEFAULT_RULES
      if (selected) {
        rules = rules.filter(r => selected.includes(r.name))
      }
      if (excluded) {
        rules = rules.filter(r => !excluded.includes(r.name))
      }

      fs.writeFileSync(profileFile, rules.map(r => `${r.level}\t${r.name}`).join("\n") + "\n")
      tempProfile = profileFile
    }

    const robotBin = robotPath ?? 'robot'
    const command = [
      robotBin, 'report',
      '--fail-on', args.failOn ?? "NONE",
      '--input', inputFile ?? '',
    ]
    if (catalogPath) {
      command.push('--catalog', catalogPath)
    }
    if (tempProfile) {
      command.push('--profile', tempProfile)
    }
    if (args.reportFile) {
      command.push('--output', resolvePath(args.reportFile) ?? args.reportFile)
    }

    let result: string
    try {
      result = (await Bun.$`${command}`.text()).trim()
    } catch (e: any) {
      if (tempDir) {
        await Bun.$`rm -rf ${tempDir}`
      }
      if (tempProfile && !args.profile) {
        await Bun.$`rm -f ${tempProfile}`
      }
      return `Robot report failed: ${e.message || e}`
    }

    if (tempDir) {
      await Bun.$`rm -rf ${tempDir}`
    }
    if (tempProfile && !args.profile) {
      await Bun.$`rm -f ${tempProfile}`
    }

    let output = strippedNote + result

    if (args.reportFile) {
      const reportPath = resolvePath(args.reportFile) ?? args.reportFile
      try {
        const raw = fs.readFileSync(reportPath, "utf-8")
        const data: any[] = JSON.parse(raw)
        const counts: Map<string, number> = new Map()
        for (const entry of data) {
          const level = entry.level
          const violations = entry.violations || []
          for (const viol of violations) {
            for (const ruleName of Object.keys(viol)) {
              const items = viol[ruleName]
              if (Array.isArray(items)) {
                const key = `${level} ${ruleName}`
                counts.set(key, (counts.get(key) || 0) + items.length)
              }
            }
          }
        }
        const summaryLines: string[] = []
        summaryLines.push("")
        summaryLines.push("Report JSON schema: array of {level, violations:[{<rule_name>:[{subject,...}]}]}.")
        summaryLines.push("Report summary (by rule):")
        const sorted = Array.from(counts.entries()).sort((a, b) => {
          const order: Record<string, number> = { ERROR: 0, WARN: 1, INFO: 2 }
          const aLevel = a[0].split(" ")[0]
          const bLevel = b[0].split(" ")[0]
          return (order[aLevel] ?? 3) - (order[bLevel] ?? 3) || b[1] - a[1]
        })
        for (const [key, count] of sorted) {
          const [level, rule] = key.split(" ", 2)
          summaryLines.push(`  ${level.padEnd(5)} ${rule}: ${count}`)
        }
        output += summaryLines.join("\n")
      } catch {
        output += "\nWARNING: could not parse report JSON for summary."
      }
    }

    return output
  }
})
