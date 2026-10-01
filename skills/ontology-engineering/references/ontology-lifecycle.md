# Ontology Lifecycle & Verification

This guide covers the engineering principles behind construction, annotation, and verification of robust ontologies.

## 1. Merging & Imports

### Merging with ROBOT
When combining multiple ontologies, always prefer **ROBOT merge** over `rdflib` concatenation. ROBOT handles import resolution and semantic consistency correctly.

### Import Resolution
* **ROBOT/Java OWL API:** Automatically resolves imports using local `catalog-v001.xml` or `catalog.xml` files found in the ontology directory.
* **rdflib:** Does **not** resolve catalog-based imports. Concatenating files with `rdflib` often results in profile violations like `multiple_labels`.

## 2. The Annotation Protocol

Annotations are essential for both human readability (CNL) and machine interoperability. 

### The Importance of Declaration
A critical engineering practice is the explicit declaration of all annotation properties as `owl:AnnotationProperty`. Failure to do so prevents reasoning tools (like `pyhornedowl`) from discovering and processing these annotations during review or verbalization.

## 3. Verification Sequence

After construction, follow this sequence to ensure ontology quality:

1. **Syntax & Profile Check**: Use `check-ontology` to catch OWL syntax errors and ensure compliance with your target profile (e.g., OWL 2 DL).
2. **CNL Spot-check**: Use `verbalize-ontology-class` to verify that key classes render correctly in Controlled Natural Language. This catches errors in logical definition accuracy.
3. **Hierarchy Audit**: Use `find-ontology-class` to audit term counts and ensure the inferred hierarchy matches domain expectations.
4. **Curation Status**: Use `set-annotation` to ensure all classes have a clear curation status (e.g., `IAO_0000123` for incomplete, `IAO_0000122` for ready).
