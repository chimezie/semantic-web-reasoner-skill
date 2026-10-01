---
name: semantic-web-agent
description: Handles RDF, OWL, N3, RIF, and SPARQL including entailment regimes. Applies semantic web standards, generates reasoning proofs, and validates ontologies. Use when working with Turtle, N3, RDF/XML, OWL 2 RL, RIF, SPARQL queries, or when needing to inspect, reason over, or annotate semantic web data - even if they don't explicitly say "semantic web".
---

# Semantic Web Agent

The Semantic Web is an extension of the Web of Data with logic-based knowledge representation to facilitate machine understanding and automation.

Whenever possible, use RDF, the primary data model. Capture RDF in Turtle, N3, RDF/XML, NT, and Trix. Use Jena [riot](https://jena.apache.org/documentation/io/) to convert between these formats.

Prefer declarative linked data (identified by resolvable URIs).

Semantic web agents (task-driven or independent) interact with a semantic web and facilitate intelligent behavior. While agents inherit principles from the earlier era of **Expert Systems** (symbolic knowledge, modularity, and explainability), they utilize modern standards like RDF and OWL to achieve this.

## Expert System Principles (Inherited)

Agents follow these core principles through semantic web technologies:
- **Explicit Knowledge**: Represent knowledge via explicit RDF triples and axioms.
- **Modularity**: Keep elements of the knowledge base (ontologies) independent and modular.
- **Separation of Concerns**: Separate the knowledge base (TBox/ABox) from the reasoning engines (interpreters).
- **Explainability**: Provide justifications for inferences (e.g., via `class-entailments` proofs).

## Vocabularies and Ontologies

Model ontologies as classes plus property restrictions.

For verbose ontology exchange formats (like RDF/XML), **do not read text content directly** (e.g., with `grep`) but use this skill's tools to understand structure.

Use `ontology-report` for a bird's eye view, and `find-ontology-class`/`find-ontology-property` for term searching via substring or regex. Use `check-ontology` and `ontology-measure-essentials` for validation.

Pair RDF data with consensus knowledge (curated ontologies) to facilitate interoperability and serendipitous automation.

## Tool Use

The `ontologyUri` argument refers to an ontology persisted in SQLite (via `create-ontology`) or a local OWL file. It must not have a trailing `#`.

The `baseuri` argument is used with `byId` to form an IRI by concatenating both and allowing reference to a local name (e.g., for `get-annotation`, `verbalize-ontology-class`, and `class-entailments`). It should end in `#` or `/`.

**pyhornedowl** (used by OWL_DSL) and the Java OWL API fail if `owl:imports` points to unreachable PURLs. Keep required import files locally or use a `catalog-v001.xml`. See [Protege and XML Catalogs](https://protegewiki.stanford.edu/wiki/Importing_Ontologies_in_P41#Protege_and_XML_Catalogs).

The `configurationFile` argument is optional. Prefer ontology-embedded `OWL_DSL_*` annotations for CNL information. The YAML config is a supplement, auto-discovered as `<stem>.cnl.yaml`. See [CNL Configuration](references/cnl-configuration.md).

The ELK reasoner may time out on ontologies with >50K triples. Mitigate by splitting core upper ontologies from their imports.

Validate with: `ontology-report` → `verbalize-ontology-class` → `check-ontology`.

## Primary Workflows

Use the following reference guides to implement the correct semantic web workflow.

### 1. SPARQL Entailment & Hybrid Querying
Use when querying remote RDF datasets using local RDF, RDFS, OWL 2, etc. semantics.
- **Guide:** [FuXi SPARQL Entailment](references/fuxi-entailment.md)

### 2. Ontology Development & Construction
Use when creating or extending a taxonomy from structured data.
- **Guide:** [Ontology Development Guide](references/ontology-development.md)

### 3. Semantic Web Fundamentals
Use for core concepts regarding URIs, namespaces, and serialization.
- **Guide:** [Semantic Web Basics](references/semantic-web-basics.md)

### 4. Slicing and dicing RDF files
Use for mass converting or performing semantic data management using the FuXi CLI.
- **Guide:** [FuXi CLI](references/fuxi-cli.md)

### 5. Ontology Tool Workflows
Use when inspecting an ontology, running the reasoner, or querying remote data.
- **Guide:** [Ontology Tool Workflows](references/workflows.md)

### 6. CNL Configuration
Use when configuring Manchester OWL to CNL rendering via `OWL_DSL_*` annotations or YAML.
- **Guide:** [CNL Configuration](references/cnl-configuration.md)

### 7. Check Ontology Reference
Use when interpreting `check-ontology` ROBOT report rules and `ontology_db.json` semantics.
- **Guide:** [Check Ontology Reference](references/check-ontology-reference.md)

