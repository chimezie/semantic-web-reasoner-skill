# Reasoning Fundamentals

This guide provides the logical foundations for interacting with OWL 2 ontologies and interpreting reasoning results.

A TBox holds intensional constraints (GCIs, role/domain/range restrictions); an ABox holds extensional assertions. Classification computes the TBox subsumption hierarchy. In EL++, subsumption is inter-reducible with satisfiability, ABox consistency, and instance checking.

## 1. The Logic: OWL 2 EL Inference Rules

When using a reasoner (e.g., ELK), the engine applies these rules to derive new knowledge. Understanding these rules is essential for interpreting entailment explanations.

| Rule | Pattern | Meaning |
|---|---|---|
| **Subsumption** | A ⊑ B, B ⊑ C ⇒ A ⊑ C | Class hierarchy is transitive |
| **Conjunction** | A ⊑ B, A ⊑ C ⇒ A ⊑ B ⊓ C | A is a subclass of both B and C |
| **Existential** | A ⊑ ∃r.C, C ⊑ D ⇒ A ⊑ ∃r.D | Restriction propagates up the hierarchy |
| **Equivalence** | A ≡ B ⇒ A ⊑ B and B ⊑ A | Defined classes are symmetric |
| **Conjunction Inference** | A ⊑ B ⊓ C ⇒ A ⊑ B and A ⊑ C | A inherits from each conjunct |
| **Role Inclusion** | r ⊑ s, A ⊑ ∃r.C ⇒ A ⊑ ∃s.C | Transitive/hierarchical roles stay tractable |
| **Bottom/Nominal** | A ⊑ ⊥ ⇒ A unsatisfiable | `owl:Nothing` and single `objectOneOf` allowed; `ObjectAllValuesFrom` excluded |

*Note: A, B, C, D are classes; r, s are object properties. ⊑ = `rdfs:subClassOf`, ≡ = `owl:equivalentClass`, ∃r.A = `owl:someValuesFrom`.*

Stay tractable: reflexive roles and range restrictions need a syntactic restriction. Symmetric/inverse roles make subsumption ExpTime-complete; unrestricted range with role inclusions is PSpace-hard to undecidable.

---

## 2. Interpreting Reasoning Results

A reasoning trace maps logical steps to the inference rules defined above.

### Example Proof: Deriving D ⊑ E

**Given Axioms:**
[1] A ≡ ∃r.B
[2] C ⊑ B ⊓ H ⊓ I
[3] D ≡ ∃r.C ⊓ G
[4] E ≡ A ⊓ F
[5] D ⊑ F ⊓ J
[6] D ⊑ K

**Proof Trace:**

| Step | Premises | Conclusion | Justification |
|---|---|---|---|
| **1** | [1], [2], [3] | D ⊑ A | D ⊑ ∃r.C ∧ C ⊑ B ⇒ D ⊑ ∃r.B; ∃r.B ⊑ A ⇒ D ⊑ A |
| **2** | STEP1, [4], [5] | D ⊑ E | D ⊑ A ∧ D ⊑ F ⇒ D ⊑ A ⊓ F; A ⊓ F ⊑ E ⇒ D ⊑ E |

---

## 3. Structured Derivation Prompt (DSL Format)

When generating a logical derivation from a set of axioms, use the following structured prompt to produce a clear, step-by-step explanation. This format is designed for integration into agent toolchains that require machine-parseable proof output while remaining human-readable.

```
You are an expert in logical reasoning. Your task is to
produce a clear and easily understandable explanation that
demonstrates how the conclusion logically follows from the
given axioms.

(Inference rules here if applied)

## Output Format Requirements

AXIOMS_USED: {list of axiom identifiers}

SIMPLIFY:
[axiom_id]: [original_axiom] → [simplified_form]

...

DERIVE:
STEP[n]: [premise_list] ⊢ [conclusion]
EXPLANATION: [a simple explanation of the derivation]
...
```
(Source: Yang, Hui, Jiaoyan Chen, and Uli Sattler. "Large Language Model for OWL Proofs." arXiv preprint arXiv:2601.12444 (2026).)
