# BFO Modeling Patterns from Otte, Beverley & Ruttenberg (2021), "Basic Formal Ontology: Case Studies"

Source: J. Neil Otte, John Beverley, Alan Ruttenberg, "Basic Formal Ontology: Case Studies" (2021), philarchive.org/archive/OTTBBF.

## When to Use
Load this file when modeling:
- **Constitution/Composition** (material and part relationships)
- **Role Change** (social or organizational roles)
- **Quality Change** (attributes changing over time)
- **Sub-Process Structure** (process decomposition)
- **Goal-Directed Action** (plans, objectives, and intentions)
- **Evolving Social/Legal Roles** (regulatory and deontic changes)

## Using BFO

When using BFO, import it using this URL: `http://purl.obolibrary.org/obo/bfo.owl` and RO via `http://purl.obolibrary.org/obo/ro.owl` (if needed):

```owl
<owl:Ontology rdf:about=".. ontology URL (or empty string to resolve against Base URL of the ontology file) ">
    <owl:imports rdf:resource="http://purl.obolibrary.org/obo/bfo.owl"/>
    <owl:imports rdf:resource="http://purl.obolibrary.org/obo/ro.owl"/> <!-- if needed -->
</owl>
```

## Ontology of Information Entities

When the domain being modeled involves information entities, use and import the information Artifact Ontology (IAO), which is aligned with BFO, RO, and can be imported from `https://purl.obolibrary.org/obo/iao.owl`

## Pattern 1: Constitution/Composition ("made of" relations)

**Context**: Modeling the relationship between a material entity and its components.

**Steps**:
1. Represent the material (e.g., wood) as a `material entity` instance.
2. Represent parts (e.g., legs) as `continuant part of` the material at specific time intervals.
3. Represent the artifact (e.g., "table") as a function-bearing condition: the material entity is a `bearer of` a function (e.g., "table function") for as long as that class applies.

**Template**: 
`X =def a material entity that is bearer of <artifact function>`

**Anti-pattern**: 
- Inventing a primitive "made of" or "constituted by" relation.
- Asserting an artifact class as a direct subclass of a material entity.

**Validation**: 
- Run the reasoner to ensure the artifact class is correctly inferred as a defined class rather than a primitive subclass.

## Pattern 2: Role Change (organizational/social roles)

**Context**: Modeling roles that are separable from their bearers.

**Steps**:
1. Model role-bearers (persons, organizations) as independent continuants (`object`, `object aggregate`).
2. Model the role itself (e.g., "teacher role") as a `role` (specifically dependent continuant) that `inheres in` exactly one bearer at a time.
3. Model the transition (e.g., resignation) as a process that creates/destroys the role instance.

**Template**: 
`bearer of(Person, RoleInstance) at <temporal_interval>`

**Anti-pattern**: 
- Creating a role as a permanent property or subclass of a bearer (e.g., `Teacher subClassOf Person`).

**Validation**: 
- Verify that the role instance is a specifically dependent continuant and is not a permanent attribute of the bearer.

## Pattern 3: Quality Change (property/attribute change over time)

**Context**: Modeling attributes that change without changing the underlying entity.

**Steps**:
1. Model the changing attribute (e.g., color) as a single, enduring `quality` particular.
2. Use the `instance of` relation to link the quality particular to different lower-level quality types (e.g., "red", "brown") across different temporal sub-intervals.
3. Pair the quality change with a co-occurring process (e.g., "withering") for causal context.

**Template**: 
`QualityInstance instance of <QualityType> at <temporal_interval>`

**Anti-pattern**: 
- Deleting one quality instance and creating a new one to represent a change in state.

**Validation**: 
- Check that the quality particular persists through the transition in the temporal hierarchy.

## Pattern 4: Sub-Process Structure (process decomposition)

**Context**: Decomposing a composite process into simpler components.

**Steps**:
1. Decompose a composite process (e.g., "locomotion") into `proper occurrent part of` sub-processes (e.g., "walking").
2. Distinguish `occurrent part of` (spatially differing) from `temporal part of` (spatially coextensive) based on the parts' extent.
3. Define sub-process classes using necessary-and-sufficient conditions on manner or rate.

**Template**: 
`<SubProcess> subClassOf (<Process and (hasManner some <Manner>))`

**Anti-pattern**: 
- Asserting sub-processes as arbitrary siblings without logical definitions.

**Validation**: 
- Confirm sub-process classes are defined via logical restrictions rather than hand-asserted taxonomy.

## Pattern 5: Goal-Directed Action (plans and objectives)

**Context**: Modeling the relationship between agents, plans, and outcomes.

**Steps**:
1. Model a `plan` as a `realizable entity` that `inheres in` an agent.
2. Model the `plan specification` as an information content entity that is `concretized by` the plan particular.
3. Model success/failure via the `achieves planned objective` relation between a `planned process` and its `objective specification`.

**Template**: 
`<PlanSpecification> concretized by <PlanParticular>`

**Anti-pattern**: 
- Conflating the plan (the entity) with the plan specification (the information).

**Validation**: 
- Verify that the plan and plan specification are distinct entities in the hierarchy.

## Pattern 6: Evolving Social/Legal Roles (deontic roles)

**Context**: Modeling changes in regulations, laws, or social powers.

**Steps**:
1. Distinguish between the process (the act), the information (the law), and the roles (the powers) created by a social act.
2. Model legal instruments (e.g., licenses) as `document` subclasses of `information content entity`.
3. Model regulatory changes as new `action regulation` instances that create or revoke `deontic role` instances.

**Template**: 
`<Document> is specified output of <SocialAct>`

**Anti-pattern**: 
- Overwriting existing roles when a regulation changes; instead, layer new regulation instances.

**Validation**: 
- Ensure regulatory changes are modeled as new instances rather than modifications to existing role particulars.

## General Formalization Conventions

- **Time-Indexing**: All time-indexed relations (`instance of`, `continuant part of`, `bearer of`) must take a temporal interval/instant argument.
- **Measurement**: Model measurements using a `generically dependent continuant` (measurement information) that is `concretized by` an `information bearing entity` carrying the value.
- **Relation Reuse**: Reuse existing relations from CCO, OBI, IAO, and D-Acts (e.g., `has specified output`, `achieves planned objective`) before minting new ones.
