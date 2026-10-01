---
name: ontology-engineering
description:  Normalizes OWL 2 ontologies via Rector implementation normalisation, BFO alignment, and RO reuse. Builds homogeneous primitive skeleton trees distinguishing self-standing vs partitioning concepts, EquivalentTo definitions in Manchester Syntax, disjointness/covering axioms, and EL++-safe TBox hierarchies. Use when building OWL ontologies, aligning to BFO, de-tangling polyhierarchies, choosing EL/QL/RL profiles, modeling roles/processes/change-over-time, biomedical anatomy/disease modeling, or upon mention of ontology, EL, Description Logic, EquivalentTo, SubClassOf, disjointness, Nothing, nominals, GCIs, transitive roles, inverse/symmetric roles, annotation properties, or reasoner - even if they don't say ontology engineering.
---

# Ontology Engineering

## Core Principle: Two Orthogonal Concerns

When designing or reviewing a class, evaluate it against two independent questions. Conflating them is a primary source of modeling errors:

1.  **Ontological Placement**: What kind of entity is this in the context of a top-level ontology (e.g., BFO)? (e.g., continuant vs. occurrent, independent vs. dependent).
2.  **Implementation Normalization**: How should the class's position in the domain hierarchy be represented: as an asserted primitive, or an inferred defined class?

## Rector Normalization: Decompose Before You Assert

To achieve implementation normalisation, decompose the domain into independent, disjoint "skeleton taxonomies" that are restricted to simple, homogeneous trees.

1.  **Identify compositional classes.** Any class whose meaning is "X that has/is-related-to Y" (e.g., "cardiac disease") is a candidate for normalization.
2.  **Extract primitive skeleton trees.** Build simple trees where:
    - No domain concept has more than one primitive parent.
    - Each branch is homogeneous (e.g., all subsumption, not a mix of partonomy and subsumption).
    - Concepts are either **Self-standing** (open sets, no covering) or **Partitioning** (exhaustive, disjoint covering sets).
3.  **Write logical definitions.** Use `EquivalentTo` to combine primitive classes via existential restrictions.
    *Example (Manchester Syntax):*
    ```manchester
    Fracture and (has_location some Femur)
    ```
4.  **Use the Relation Ontology (RO).** Reuse existing relations from [RO](http://purl.obolibrary.org/obo/ro.owl) rather than inventing new ones.
5.  **Add explicit disjointness.** Assert disjointness among sibling primitives (especially self-standing ones) to allow the reasoner to catch modeling errors.
6.  **Prefer prospective normalization.** Design new classes with logical definitions from the start.

## OWL 2 Profile Selection

Select the appropriate profile to balance expressivity and reasoning efficiency:

| Profile | Best Use Case | Key Restrictions / Notes |
| :--- | :--- | :--- |
| **OWL 2 DL** | General purpose reasoning | The standard for most complex modeling tasks. |
| **OWL 2 EL** | **Biomedical/Large TBox classification** (e.g., SNOMED) | Allows `Nothing`, single nominals, GCIs, transitive/hierarchical roles. **Avoid**: `ObjectAllValuesFrom`, inverse/symmetric roles, cardinality, disjunction/negation. Range/reflexive only with syntactic restriction. |
| **OWL 2 QL** | **Large ABox/Querying** | Optimized for SQL-based query rewriting via RDBMS. |
| **OWL 2 RL** | **Rule-based reasoning** | Designed for scalable reasoning using rule engines. |

## General Workflow

Assume the following namespace prefix bindings:
- `obo`: http://purl.obolibrary.org/obo/
- `rdfs`: http://www.w3.org/2000/01/rdf-schema#

1.  **Classify the term.** Determine its ontological category (e.g., via a top-level ontology) and justify its placement.
2.  **Determine complexity.** Identify if the class is **Primitive** (place it in the appropriate skeleton tree via asserted `subClassOf` only) or **Compositional** (decompose it into constituent primitive-tree classes plus relations, and write a logical definition).
3.  **Select Profile.** Choose an OWL 2 profile (EL, QL, RL, or DL) based on domain scale and reasoning requirements.
4.  **Verify relations.** Check for an existing reusable relation (RO or the ontology's own property hierarchy) before minting a new object property.
5.  **Write definitions.** Use Manchester Syntax to draft `EquivalentTo` axioms for compositional classes.
6.  **Reason and Verify.** Run the reasoner. Confirm the inferred is-a hierarchy matches domain-expert expectations.
7.  **Finalize and Annotate.** Add disjointness axioms among sibling primitives and add rich annotations (see below).

## Annotation

Add annotations to ensure machine understandability and human readability. Use FuXi's InfixOwl to declare annotation properties:

```python
from fuxi.Syntax.InfixOWL import AnnotationProperty, GraphContext
with GraphContext(graph, {}):
    property = AnnotationProperty(property_uriref_instance)
```

Standard properties include:
- `rdfs:label`: The human-readable, commonly accepted label.
- `skos:prefLabel`: The preferred lexical label.
- `obo:IAO_0000115`: The gold-standard formal definition.
- `rdfs:comment`: Commentary regarding provenance or usage.
- `rdfs:seeAlso`: Links to additional resources.

## Specialized Guidance (Triggers)

### BFO-Specific Engineering
**Trigger:** When modeling in BFO, aligning to BFO, or when BFO-style normalization is preferred.
- Consult `references/bfo-case-study-patterns.md` for category placement and modeling change over time.

### Biomedical Ontology Modeling
**Trigger:** When performing ontology engineering specifically for the biomedical domain (e.g., anatomy, disease, organism, cellular processes, etc.).
- Consult `references/biomedical-ontology-modeling.md` for domain-specific modeling conventions, normalization strategies, and terminology standards.

### Reasoning Fundamentals
**Trigger:** When interpreting reasoner entailments, reading a proof trace, or needing the OWL 2 EL inference rules.
- Consult `references/reasoning-fundamentals.md` for the rules table, a worked proof example, and the structured derivation prompt.

### Ontology Lifecycle
**Trigger:** When merging ontologies, resolving imports, declaring annotation properties, or verifying a built ontology.
- Consult `references/ontology-lifecycle.md` for merge/import practices, annotation declarations, and the verification sequence.

## Common Errors to Avoid

- **Asserting multiple parents by hand:** Instead, derive multiple inheritance via a reasoner from correct logical definitions.
- **Inhomogeneous placement:** Mixing different types of specialization (e.g., partonomy and subsumption) in a single primitive branch.
- **Incorrect covering/closure:** Treating self-standing concepts as exhaustive (covering) or partitioning concepts as open.
- **Borrowing category placements blindly:** Never adopt a placement from a non-BFO or pre-BFO source without re-verifying it against the chosen top-level ontology's axioms.
- **Over-normalizing:** Not every domain distinction is compositional. Do not force a logical definition onto a genuinely primitive term.
- **Skipping disjointness axioms:** This silently defeats the reasoner's ability to catch inconsistent placements.
- **Domain/Range conflicts:** Creating range/domain constraints that unintentionally force multiple primitive parents.

