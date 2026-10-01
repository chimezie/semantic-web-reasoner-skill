import { Plugin } from "@opencode-ai/plugin"
import checkOntology from "./check-ontology.js"
import classEntailments from "./class-entailments.js"
import createOntology from "./create-ontology.js"
import dirOntology from "./dir-ontology.js"
import extractClass from "./extract-class.js"
import findOntologyClass from "./find-ontology-class.js"
import findOntologyProperty from "./find-ontology-property.js"
import getAnnotation from "./get-annotation.js"
import listOntologies from "./list-ontologies.js"
import ontologyMeasureEssentials from "./ontology-measure-essentials.js"
import ontologyReport from "./ontology-report.js"
import setAnnotation from "./set-annotation.js"
import sparqlInterlocution from "./sparql-interlocution.js"
import verbalizeOntologyClass from "./verbalize-ontology-class.js"

const MySkillPlugin: Plugin = async () => {
  return {
    tool: {
      "check-ontology": checkOntology,
      "class-entailments": classEntailments,
      "create-ontology": createOntology,
      "dir-ontology": dirOntology,
      "extract-class": extractClass,
      "find-ontology-class": findOntologyClass,
      "find-ontology-property": findOntologyProperty,
      "get-annotation": getAnnotation,
      "list-ontologies": listOntologies,
      "ontology-measure-essentials": ontologyMeasureEssentials,
      "ontology-report": ontologyReport,
      "set-annotation": setAnnotation,
      "sparql-interlocution": sparqlInterlocution,
      "verbalize-ontology-class": verbalizeOntologyClass,
    },
  }
}

export default MySkillPlugin