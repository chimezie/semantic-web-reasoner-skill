# Biomedical ontologies

To the extent possible, re-use existing, domain-expert authored biomedical ontologies and their terms.  In particular, consider the following, shown with the domain they cover

## SNOMED CT

It is a detailed, multilingual clinical terminology that covers the entire domain of clinical medicine and electronic health record (EHR) documentation, an ontology, a building block for semantic interoperability, and is the most comprehensive clinical terminology in the world.

There is no publicly available or importable version of it, but it should still be used as a reference.

## The Foundational Model of Anatomy (FMA)

It is an ontology comprising the terms needed for symbolic representation of the phenotypic structure of the human body in a form that is understandable to humans and is also navigable, parseable and interpretable by machine-based systems.  It is a domain ontology that represents a coherent body of explicit declarative knowledge about human anatomy. Its ontological framework can be applied and extended to all other species.

The current version of it can be imported or downloaded from: http://purl.org/sig/ont/fma.owl

## Gene Ontology (GO)

The Gene Ontology (GO) is a structured, standardized representation of biological knowledge. GO describes concepts (also known as terms, or formally, classes) that are connected to each other via formally defined relations. The GO is designed to be species-agnostic to enable the annotation of gene products across the entire tree of life. The computational framework of the GO enables consistent gene annotation, comparison of functions across organisms, and integration of knowledge across diverse biological databases.

The current version of it can be imported or downloaded from: https://purl.obolibrary.org/obo/go.owl

# Understanding medical terminology

Delegate the actual medical reasoning to the `medical-concept` subagent via the Task tool rather than answering directly when a task requires interpreting, defining, or mapping an unfamiliar medical or clinical concept, including but not limited to:
- Disambiguating clinical terminology in free text
- Mapping natural-language concepts to terms in existing biomedical ontologies
- Verifying whether two clinical terms are semantically equivalent
- Explaining clinical semantics needed to complete a non-medical task (e.g., a data-pipeline or ontology-engineering task that touches healthcare data)

Use it especially if the reasoning involves any of the biomedical ontologies above or the International Classification of Diseases, Tenth Revision, Clinical Modification (ICD-10-CM) which is used to code and classify medical diagnoses.  

Formulate a specific, self-contained question for the subagent (it does not have access to your current context), so include any relevant snippet or code inline in the delegated task description. 

