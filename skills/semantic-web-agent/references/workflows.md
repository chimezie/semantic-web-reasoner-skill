# Ontology Tool Workflows

This guide outlines the primary operational workflows for interacting with and using OWL ontologies.

## 1. Workflow A: Inspection & Review (pyhornedowl)

**Best for:** Rendering Manchester OWL syntax, finding classes/properties, and linting.
**Requirement:** None (reads `.owl` files directly).

1. **Open OWL file** — provide the path via the `owlFile` argument.
2. **Analyze vocabulary** — use `verbalize-ontology-class`, `find-ontology-class`, or `find-ontology-property`.

---

## 2. Workflow B: Logical Reasoning (owlready2)

**Best for:** Generating logical entailment explanations and verifying subsumption.
**Requirement:** Requires a SQLite database generated from the OWL file.

1. **Create SQLite database** — use `create-ontology` to load the OWL file into a SQLite backend.
2. **Explain entailments** — use `class-entailments` to run the ELK reasoner and generate justifications.
3. **Clean up** — use `destroy_sqlite` to remove the temporary SQLite file.
4. **Verify** — ensure the `class-entailments` output provides a valid step-by-step logical proof.

---

## 3. Workflow C: Hybrid SPARQL (Remote EDB + Local TBox)

**Best for:** Querying remote RDF datasets (the "Entity Database" or EDB) using local OWL semantics (the "Terminology" or TBox).

1. **Analyze vocabulary** — use the **Inspection Workflow** to understand the TBox and the **Logical Reasoning Workflow** to understand logical entailments it facilitates.
2. **Prepare data** — parse N-Quads using `rdflib.Dataset()` and flatten them into a single `Graph`.
3. **Discover EDB predicates** — run `SELECT DISTINCT ?pred WHERE { ?s ?pred ?o } LIMIT 50` on the remote endpoint to identify available properties.
4. **Write N3 bridge rules** — derive semantic predicates from EDB predicates (see the FuXi SPARQL Entailment guide, already listed in SKILL.md routing).
5. **Execute query** — use `sparql-interlocution` with the endpoint, bindings, query, local OWL file, and N3 rules.
6. **Verify** — confirm that SPARQL results align with the expected OWL entailments.

**Note on Profile**: To ensure efficient DLP compilation and SPARQL entailment compatibility, ensure the TBox (ontology) is in the **OWL 2 RL** profile.
