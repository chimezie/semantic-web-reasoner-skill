---
name: semantic-web-agent
description: >-
  Use when working with RDF, OWL, N3, RIF, SPARQL queries, services, or entailment
  regimes; Turtle, N3, RDF/XML, or OWL 2 RL serializations; linked data,
  knowledge graphs, or semantic web data; or when you need to inspect, reason
  over, annotate, or validate an ontology, even if the user does not say
  "semantic web". Applies semantic web standards, generates reasoning proofs,
  and validates ontologies.
compatibility: >-
  Bundled helper scripts run with uv (PEP 723 inline dependencies, Python 3.11+;
  rdflib, plus fuxi for sparql-interlocution). Tools such as ontology-report and
  check-ontology come from OWL_DSL and must be installed separately.
---

# Semantic Web Agent

The Semantic Web extends the Web of Data with logic-based knowledge representation. Use RDF as the primary data model, serialize it as Turtle, N3, RDF/XML, NT, or TriX, and convert between formats with Jena [riot](https://jena.apache.org/documentation/io/):

```console
riot --syntax=turtle --output=nquads input.nq 2>/dev/null > clean.nq
```

Prefer declarative linked data:
- **Unambiguous identifiers**: Use separate URIs for real-world objects and the documents that describe them.
- **Cool URIs**: Prefer stable, mnemonic URIs. Use hash URIs (`#`) with 303 redirects for large-scale instance data.
- **Linking**: Connect resources via authoritative links (e.g., `rdfs:isDefinedBy`, `foaf:page`) so agents can follow their nose.

For ontologies in verbose exchange formats such as RDF/XML, do not read text with `grep`; use the inspection tools to understand structure.

## Tool access

In OpenCode, call the named custom tools directly. In Claude Code or any agent without those tools, run the bundled helpers through Bash with paths relative to this skill's directory, for example `uv run scripts/get-annotation.py ...` or `python3 scripts/get-annotation.py ...`.

| Bundled with this skill (run via Bash) | Provided by [OWL_DSL](https://github.com/chimezie/owl_dsl) (install separately) |
| --- | --- |
| `create-ontology`, `dir-ontology`, `list-ontologies`, `get-annotation`, `set-annotation`, `sparql-interlocution` | `ontology-report`, `verbalize-ontology-class`, `find-ontology-class`, `find-ontology-property`, `check-ontology`, `ontology-measure-essentials`, `class-entailments`, `extract-class`, and the `set-*` annotation tools |

### Ontology arguments

The ontology tools share many common arguments.

The `ontologyUri` argument refers to an ontology persisted in SQLite (via `create-ontology`) or a local OWL file. It must not have a trailing `#`.

The `baseuri` argument is used with `byId` to form an IRI by concatenating both and allowing reference to a local name (e.g., for `get-annotation`, `verbalize-ontology-class`, and `class-entailments`). It should end in `#` or `/`.

**pyhornedowl** (used by OWL_DSL) and the Java OWL API fail if `owl:imports` points to unreachable PURLs. Keep required import files locally or use a `catalog-v001.xml`. See [Protege and XML Catalogs](https://protegewiki.stanford.edu/wiki/Importing_Ontologies_in_P41#Protege_and_XML_Catalogs).

The `configurationFile` argument is optional. Prefer ontology-embedded `OWL_DSL_*` annotations for CNL information on how they are verbalized. The YAML config is a supplement, auto-discovered as `<stem>.cnl.yaml`. See [CNL Configuration](references/cnl-configuration.md).

The ELK reasoner may time out on ontologies with more than 50K triples. Split core upper ontologies from their imports.

### Inspecting ontologies

Use `ontology-report` for an overview, `find-ontology-class` / `find-ontology-property` to search terms by substring or regex, and `check-ontology` / `ontology-measure-essentials` for validation. Model ontologies as classes plus property restrictions, and pair RDF data with curated consensus ontologies so it interoperates with established knowledge.

### Running the bundled helpers

Run `get-annotation` with the OWL file, base URI, class reference, `true` for a local name or `false` for an `rdfs:label`, and the annotation property whose value you want to retrieve:

```bash
uv run scripts/get-annotation.py \
  ontology.owl \
  "https://example.org/ontology#" \
  Disease \
  true \
  skos:prefLabel
```

Run `sparql-interlocution` with the endpoint URL, a namespace prefix map, the query, and the local TBox file:

```bash
uv run scripts/sparql-interlocution.py \
  "https://dbpedia.org/sparql" \
  '{"dbo": "http://dbpedia.org/ontology/"}' \
  'SELECT ?s WHERE { ?s a dbo:Person } LIMIT 10' \
  ontology.owl \

```

`uv` reads each script's inline dependencies. Without `uv`, install `rdflib` (and `fuxi` for `sparql-interlocution`) and run the scripts with `python3`.

### Validation loop

Run these steps in order. After fixing any failure, restart from step 1.

1. **`ontology-report`** — produce a bird's-eye report of entities and axioms. Failure: the report shows missing entities/axioms or structural errors. Fix the source ontology, then restart from step 1.
2. **`verbalize-ontology-class`** — render each key class in controlled natural language. Failure: a class renders incorrectly or its definition does not match domain intent. Fix the logical definition or annotations, then restart from step 1.
3. **`check-ontology`** — run ROBOT report and profile checks. Failure: rule violations or OWL profile errors. Fix the reported axioms, then restart from step 1.

## Expert System Principles

Agents inherit these principles through semantic web technologies:
- **Explicit knowledge**: Represent knowledge as explicit RDF triples and logic-based knowledge representation.
- **Modularity**: Keep elements of the knowledge base (ontologies) independent and modular.
- **Separation of concerns**: Separate the knowledge base (TBox/ABox) from reasoning engines (interpreters).
- **Explainability**: Provide justifications for inferences (e.g., via `class-entailments` proofs).

## Workflows

| Task                                                                                                                                                | Reference |
|-----------------------------------------------------------------------------------------------------------------------------------------------------| --- |
| Run a SPARQL query against data whose vocabulary have an ontology with RDF, RDFS, OWL 2, or rule semantics for its terms (SPARQL Entailment regime) | [FuXi SPARQL Entailment](references/fuxi-entailment.md) |
| Create or extend a taxonomy from structured data                                                                                                    | [Ontology Development Guide](references/ontology-development.md) |
| Core concepts: URIs, namespaces, serialization, URI design, and linked-data publishing                                                              | [Semantic Web Basics](references/semantic-web-basics.md) |
| Performing reasoning on RDF data, local SPARQL entailment or manage vocabulary/reasoning with files with the FuXi CLI                               | [FuXi CLI](references/fuxi-cli.md) |
| Inspect an ontology, run the reasoner, or query remote data                                                                                         | [Ontology Tool Workflows](references/workflows.md) |
| Configuring how an OWL ontology is rendered (or verbalized)                                                                                         | [CNL Configuration](references/cnl-configuration.md) |
| Interpret `check-ontology` ROBOT report rules and `ontology_db.json` semantics                                                                      | [Check Ontology Reference](references/check-ontology-reference.md) |

