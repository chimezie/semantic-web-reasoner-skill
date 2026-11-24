---
name: ontology-engineering
description: >-
  Use when building OWL ontologies, aligning to BFO, de-tangling polyhierarchies,
  choosing EL/QL/RL profiles, modeling roles, processes, or change over time,
  biomedical anatomy or disease modeling, or when the user mentions ontology, EL,
  Description Logic, EquivalentTo, SubClassOf, disjointness, Nothing, nominals,
  GCIs, transitive roles, inverse or symmetric roles, annotation properties, or a
  reasoner, even if they do not say ontology engineering. Normalizes OWL 2
  ontologies via Rector implementation normalisation, BFO alignment, and RO reuse;
  builds homogeneous primitive skeleton trees that distinguish self-standing from
  partitioning concepts, EquivalentTo definitions in Manchester Syntax,
  disjointness/covering axioms, and EL++-safe TBox hierarchies.
---

# Ontology Engineering

## Core Principle: Two Orthogonal Concerns

Evaluate each class against two independent questions (conflating them causes modeling errors):

1. **Ontological placement**: What kind of entity is this in a top-level ontology such as BFO (continuant vs. occurrent, independent vs. dependent)?
2. **Implementation normalization**: Should the class's position in the domain hierarchy be an asserted primitive or an inferred defined class?

## Rector Normalization: Decompose Before You Assert

Decompose the domain into independent, disjoint "skeleton taxonomies" restricted to simple, homogeneous trees.

1. **Identify compositional classes.** Any class whose meaning is "X that has/is-related-to Y" (e.g., "cardiac disease") is a normalization candidate.
2. **Extract primitive skeleton trees.** Build simple trees where:
   - No domain concept has more than one primitive parent.
   - Each branch is homogeneous (all subsumption, not a mix of partonomy and subsumption).
   - Concepts are either **self-standing** (open sets, no covering) or **partitioning** (exhaustive, disjoint covering sets).
3. **Write logical definitions.** Combine primitive classes with `EquivalentTo` existential restrictions, for example in Manchester Syntax:
   ```manchester
   Fracture and (has_location some Femur)
   ```
4. **Reuse the Relation Ontology (RO).** Reuse existing relations from [RO](http://purl.obolibrary.org/obo/ro.owl) instead of inventing new ones.
5. **Add explicit disjointness.** Assert disjointness among sibling primitives, especially self-standing ones, so the reasoner catches modeling errors.
6. **Prefer prospective normalization.** Design new classes with logical definitions from the start.
7. **Validate the skeleton.** Run the reasoner and confirm each primitive has one parent and each defined class classifies under its intended parent. If not, fix the skeleton and restart from step 1.

## OWL 2 Profile Selection

Select the appropriate profile to balance expressivity and reasoning efficiency:

| Profile | Best Use Case | Key Restrictions / Notes |
| :--- | :--- | :--- |
| **OWL 2 DL** | General purpose reasoning | The standard for most complex modeling tasks. |
| **OWL 2 EL** | **Biomedical/Large TBox classification** (e.g., SNOMED) | Allows `Nothing`, single nominals, GCIs, transitive/hierarchical roles. **Avoid**: `ObjectAllValuesFrom`, inverse/symmetric roles, cardinality, disjunction/negation. Range/reflexive only with syntactic restriction. |
| **OWL 2 QL** | **Large ABox/Querying** | Optimized for SQL-based query rewriting via RDBMS. |
| **OWL 2 RL** | **Rule-based reasoning** | Designed for scalable reasoning using rule engines. |

## General Workflow

Assume these namespace bindings:
- `obo`: http://purl.obolibrary.org/obo/
- `rdfs`: http://www.w3.org/2000/01/rdf-schema#

1. **Classify the term.** Determine its ontological category (e.g., via a top-level ontology) and justify its placement.
2. **Determine complexity.** Mark the class **Primitive** (asserted `subClassOf` only, placed in the appropriate skeleton tree) or **Compositional** (decompose into primitive-tree classes plus relations and write a logical definition).
3. **Select the profile.** Choose OWL 2 EL, QL, RL, or DL based on domain scale and reasoning requirements.
4. **Verify relations.** Check for a reusable relation in RO or the ontology's property hierarchy before minting a new object property.
5. **Write definitions.** Draft Manchester Syntax `EquivalentTo` axioms for compositional classes.
6. **Reason and verify.** Run the reasoner and confirm the inferred is-a hierarchy matches domain-expert expectations. Use the `class-entailments` or `check-ontology` tools from the `semantic-web-agent` skill, or run `robot reason --reasoner ELK --input in.owl --output out.owl`.
7. **Finalize, annotate, and validate.** Add sibling disjointness and rich annotations, then run the `semantic-web-agent` validation loop. If it fails, fix the ontology and restart from step 1.

## Annotation

Use FuXi's InfixOwl to declare annotation properties:

```python
from rdflib import Graph, URIRef
from fuxi.Syntax.InfixOWL import AnnotationProperty, GraphContext

graph = Graph()
graph.parse("ontology.owl", format="xml")
annotation_property_iri = URIRef("http://purl.obolibrary.org/obo/IAO_0000115")

with GraphContext(graph, {}):
    annotation_property = AnnotationProperty(annotation_property_iri)
```

Standard properties:
- `rdfs:label`: The human-readable, commonly accepted label.
- `skos:prefLabel`: The preferred lexical label.
- `obo:IAO_0000115`: The gold-standard formal definition.
- `rdfs:comment`: Commentary regarding provenance or usage.
- `rdfs:seeAlso`: Links to additional resources.

## Specialized Guidance (Triggers)

| Trigger | Reference |
| --- | --- |
| Modeling in BFO, aligning to BFO, or preferring BFO-style normalization | [BFO case-study patterns](references/bfo-case-study-patterns.md) |
| Biomedical ontology engineering (anatomy, disease, organism, cellular processes) | [Biomedical ontology modeling](references/biomedical-ontology-modeling.md) |
| Interpreting reasoner entailments, reading a proof trace, or needing the OWL 2 EL inference rules | [Reasoning fundamentals](references/reasoning-fundamentals.md) |
| Merging ontologies, resolving imports, declaring annotation properties, or verifying a built ontology | [Ontology lifecycle](references/ontology-lifecycle.md) |

## Common Errors to Avoid

- **Asserting multiple parents by hand:** Derive multiple inheritance via a reasoner from correct logical definitions.
- **Inhomogeneous placement:** Mixing different types of specialization (e.g., partonomy and subsumption) in a single primitive branch.
- **Incorrect covering/closure:** Treating self-standing concepts as exhaustive (covering) or partitioning concepts as open.
- **Borrowing category placements blindly:** Never adopt a placement from a non-BFO or pre-BFO source without re-verifying it against the chosen top-level ontology's axioms.
- **Over-normalizing:** Not every domain distinction is compositional. Do not force a logical definition onto a genuinely primitive term.
- **Skipping disjointness axioms:** This silently defeats the reasoner's ability to catch inconsistent placements.
- **Domain/Range conflicts:** Creating range/domain constraints that unintentionally force multiple primitive parents.
