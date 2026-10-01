# Semantic Web Agent and Ontology Management Skills

Helper skills and scripts for Semantic Web agent and ontology engineering architecture using Expert system, Linked Data, and basic principles of World Wide Web architecture.

Provides two (OpenCode-compatible) Agent skills, plus a medical reasoning [subagent](https://opencode.ai/docs/agents/) and
[command](https://opencode.ai/docs/commands) for delegating clinical terminology questions to a terminology specialist model instead of reasoning about unfamiliar medical terms directly.

Is opinionated in which tools to use ([OWL_DSL](https://github.com/chimezie/owl_dsl), [ROBOT](https://robot.obolibrary.org/), [Fuxi-reincarnate](https://github.com/chimezie/fuxi-reincarnate), [riot](https://jena.apache.org/documentation/io/)) but provides a comprehensive Semantic Web architecture toolkit.

## Skills

### 1. [`semantic-web-agent`](skills/semantic-web-agent/SKILL.md)

Handles RDF, OWL, N3, RIF, and SPARQL including entailment regimes. Applies expert system principles and semantic web standards, generates reasoning proofs, and validates ontologies.

* Semantic Web as extension of Web of Data with logic-based Knowledge Representation; Preference for declarative linked data with resolvable URIs.
* Workflows ([`references/workflows.md`](skills/semantic-web-agent/references/workflows.md)):
  * A. Inspection & Review via `pyhornedowl`: `verbalize-ontology-class`, `find-ontology-class` / `find-ontology-property`, `ontology-report`, `check-ontology`, `ontology-measure-essentials`.
  * B. Logical Reasoning via `owlready2`/ELK: `create-ontology`, `class-entailments`, (proof trace), `destroy_sqlite`.
  * C. Hybrid SPARQL (remote EDB + local TBox): `sparql-interlocution` with N3 bridge rules; keep TBox in OWL 2 RL for DLP.
* Guides:
  * [`semantic-web-basics.md`](skills/semantic-web-agent/references/semantic-web-basics.md) : URIs, Turtle/N3/RDF-XML/N-Quads, REST/303, Linked Data
  * [`fuxi-entailment.md`](skills/semantic-web-agent/references/fuxi-entailment.md) : EDB vs IDB, `entailing_graph.query` vs `sparql_interlocution_basic_graph_pattern`
  * [`fuxi-cli.md`](skills/semantic-web-agent/references/fuxi-cli.md) : `fuxi.core`/`proof`/`owl`, `--dlp`, `--hybrid`, `--why`
  * [`ontology-development.md`](skills/semantic-web-agent/references/ontology-development.md) : InfixOWL vs plain `rdflib`, ROBOT merge
  * [`cnl-configuration.md`](skills/semantic-web-agent/references/cnl-configuration.md) : Manchester OWL to CNL rendering
  * [`check-ontology-reference.md`](skills/semantic-web-agent/references/check-ontology-reference.md) : ROBOT report rules and `ontology_db.json`
* Scripts: [`sparql-interlocution.py`](skills/semantic-web-agent/scripts/sparql-interlocution.py), [`create-ontology.py`](skills/semantic-web-agent/scripts/create-ontology.py), [`dir-ontology.py`](skills/semantic-web-agent/scripts/dir-ontology.py), [`list-ontologies.py`](skills/semantic-web-agent/scripts/list-ontologies.py), [`get-annotation.py`](skills/semantic-web-agent/scripts/get-annotation.py) / [`set-annotation.py`](skills/semantic-web-agent/scripts/set-annotation.py)

### 2. [`ontology-engineering`](skills/ontology-engineering/SKILL.md)

Normalizes OWL 2 ontologies via Rector normalisation, BFO alignment, and RO reuse. Builds skeleton trees, `EquivalentTo` definitions, disjointness/covering, EL++-safe hierarchies.

* Distinguish **ontological placement** (BFO: continuant/occurrent, independent/dependent) from **implementation normalisation** (primitive vs defined).
* Rector recipe: compositional classes via primitive skeleton trees (single primitive parent, homogeneous subsumption), `EquivalentTo` with existential restrictions (Manchester: `Fracture and (has_location some Femur)`), RO reuse, sibling disjointness, reason, and verify.
* Profile table: DL (general), EL (large TBox/SNOMED, no `ObjectAllValuesFrom`/inverse/cardinality/disjunction), QL (large ABox/SQL rewriting), RL (rule-based scalable).
* Triggers:
  * [`bfo-case-study-patterns.md`](skills/ontology-engineering/references/bfo-case-study-patterns.md) : BFO category placement and modeling change over time
  * [`biomedical-ontology-modeling.md`](skills/ontology-engineering/references/biomedical-ontology-modeling.md) : domain-specific modeling conventions
  * [`reasoning-fundamentals.md`](skills/ontology-engineering/references/reasoning-fundamentals.md) : EL inference rules and proof format
  * [`ontology-lifecycle.md`](skills/ontology-engineering/references/ontology-lifecycle.md) : merge/import practices and verification sequence

## Medical reasoning subagent and command

New supporting pair for use with medical reasoning language models:

* [`agents/medical-concept.md`](agents/medical-concept.md) (`medical-concept` subagent, `temperature: 0.2`, `edit/bash/task: deny`): clinical terminology and coding-system specialist with built-in expertise in ICD-10-CM, FMA, PDGM, OASIS, NANDA-I, and SNOMED CT. Returns short conversational answers with standard definitions only, ICD-10-CM name if defined there, owning terminology system, and synonyms. Delegate terminology disambiguation, coding-system mapping, and clinical semantics questions to it.
* [`commands/ask-medical.md`](commands/ask-medical.md) (`/ask-medical`, `agent: medical-concept`, `subtask: true`): thin wrapper that forwards `$ARGUMENTS` to the subagent.

See also: [`Defining_a_Medical-Terminology_Subagent_via_an_OpenCode.md`](Defining_a_Medical-Terminology_Subagent_via_an_OpenCode.md)
