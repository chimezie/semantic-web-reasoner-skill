# Semantic Web Agent and Ontology Management Skills

Helper skills and scripts for Semantic Web agent and ontology engineering architecture using Expert system, Linked Data, and basic principles of World Wide Web architecture.

Provides two OpenCode/Agent skills, plus a medical reasoning subagent and command (`agents/medical-concept.md`, `commands/ask-medical.md`) for delegating clinical terminology questions to a terminology specialist model instead of reasoning about unfamiliar medical terms directly.

## Skills

### 1. `semantic-web-agent` — `skills/semantic-web-agent/SKILL.md`

> Handles RDF, OWL, N3, RIF, and SPARQL including entailment regimes. Applies semantic web standards, generates reasoning proofs, and validates ontologies.

* Core idea: Semantic Web as extension of Web of Data with logic-based Knowledge Representation; Preference for declarative linked data with resolvable URIs.
* Workflows (`references/workflows.md`):
  * A. Inspection & Review via `pyhornedowl`: `verbalize-ontology-class`, `find-ontology-class` / `find-ontology-property`, `ontology-report`, `check-ontology`, `ontology-measure-essentials`.
  * B. Logical Reasoning via `owlready2`/ELK: `create-ontology` → `class-entailments` (proof trace) → `destroy_sqlite`.
  * C. Hybrid SPARQL (remote EDB + local TBox): `sparql-interlocution` with N3 bridge rules; keep TBox in OWL 2 RL for DLP.
* Guides: `semantic-web-basics.md` (URIs, Turtle/N3/RDF-XML/N-Quads, REST/303, Linked Data), `fuxi-entailment.md` (EDB vs IDB, `entailing_graph.query` vs `sparql_interlocution_basic_graph_pattern`), `fuxi-cli.md` (`fuxi.core`/`proof`/`owl`, `--dlp`, `--hybrid`, `--why`), `ontology-development.md` (InfixOWL vs plain `rdflib`, ROBOT merge), `cnl-configuration.md`, `check-ontology-reference.md`.
* Scripts: `scripts/sparql-interlocution.py`, `create-ontology.py`, `dir-ontology.py`, `list-ontologies.py`, `get/set-annotation.py`.

### 2. `ontology-engineering` — `skills/ontology-engineering/SKILL.md`

> Normalizes OWL 2 ontologies via Rector normalisation, BFO alignment, and RO reuse. Builds skeleton trees, `EquivalentTo` definitions, disjointness/covering, EL++-safe hierarchies.

* Core principle: separate **ontological placement** (BFO: continuant/occurrent, independent/dependent) from **implementation normalisation** (primitive vs defined).
* Rector recipe: compositional classes → primitive skeleton trees (single primitive parent, homogeneous subsumption) → `EquivalentTo` with existential restrictions (Manchester: `Fracture and (has_location some Femur)`) → RO reuse → sibling disjointness → reason & verify.
* Profile table: DL (general), EL (large TBox/SNOMED, no `ObjectAllValuesFrom`/inverse/cardinality/disjunction), QL (large ABox/SQL rewriting), RL (rule-based scalable).
* Triggers: `bfo-case-study-patterns.md`, `biomedical-ontology-modeling.md`, `reasoning-fundamentals.md` (EL inference rules + proof format), `ontology-lifecycle.md` (ROBOT merge, catalogs, `check-ontology` → `verbalize` → `find-class` → annotate).

## Medical reasoning subagent and command

New supporting pair for use with medical reasoning language models:

* `agents/medical-concept.md` (`medical-concept` subagent, `temperature: 0.2`, `edit/bash/task: deny`): clinical terminology and coding-system specialist with built-in expertise in ICD-10-CM, FMA, PDGM, OASIS, NANDA-I, and SNOMED CT. Returns short conversational answers only — standard definition, ICD-10-CM name if defined there, owning terminology system, and synonyms. Delegate terminology disambiguation, coding-system mapping, and clinical semantics questions to it.
* `commands/ask-medical.md` (`/ask-medical`, `agent: medical-concept`, `subtask: true`): thin wrapper that forwards `$ARGUMENTS` to the subagent.
