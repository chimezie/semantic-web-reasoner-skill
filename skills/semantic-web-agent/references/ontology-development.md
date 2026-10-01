# Ontology Development

## 1. Construction Strategies

Depending on the scale and complexity of your task, choose one of the following two methods.

### **Method A: InfixOWL (Idiomatic Development)**
**Best for:** Modeling complex axioms and interactive, programmatic ontology development

InfixOWL provides a syntactically rich, full-featured, context-managed way to build classes, properties, and axioms. It also handles the automatic declaration of annotation properties.

```python
from rdflib import Graph, Namespace, Literal
from fuxi.Syntax.InfixOWL import Class, Property, GraphContext

ex = Namespace("http://example.org/")
g = Graph()

with GraphContext(g, {"ex": ex}):
    person = Class(ex.Person, label=Literal("Person"))
    has_child = Property(ex.hasChild, domain=[person])
    
    # Complex class expression (Intersection + Existential)
    working_parent = Class(ex.WorkingParent)
    working_parent.equivalent_class = [
        Class(ex.Person) & Class(ex.Parent) & (has_child.some(Class(ex.Person)))
    ]
```
It automatically handles declaring annotation properties:

```python
from infixowl import Property
from rdflib import Literal

OBO = Namespace("http://purl.obolibrary.org/obo/")

g = Graph()
with GraphContext(g, {"obo": OBO}):
    #Use declare_annotation_property method to trigger declaration of annotation type
    annotation_property = Property(OBO.IAO_0000115, label = Literal("Definition")).declare_annotation_property(OBO.IAO_0000115)
```


### **Method B: Plain `rdflib` (Bulk Bootstrapping)**
**Best for:** Building large taxonomy stubs (100+ classes with minimal OWL axioms) from structured data (XML, JSON, CSV).

When building large taxonomies, plain `rdflib.Graph` is significantly faster than InfixOWL but doesn't add supporting OWL and annotation properties automatically as InfixOWL does

**Workflow for Bulk Construction:**
1.  **Parse** source data (using `json`, `csv`, or `ElementTree`).
2.  **Initialize** an empty `rdflib.Graph`.
3.  **Iterate** through terms and add:
    *   `rdf:type owl:Class`
    *   `rdfs:label`
    *   `rdfs:subClassOf` (the parent link)
    *   Other annotations (see below)

---

## 2. The Annotation Protocol

Annotations are essential for both human readability (CNL) and machine interoperability. For the full CNL annotation reference, see the CNL Configuration guide listed in SKILL.md routing. For the annotation-protocol rationale, see the ontology-engineering skill's lifecycle guide.

### **InfixOWL (Automatic)**
Using `set_annotation()` inside a `GraphContext` automatically handles the `owl:AnnotationProperty` declaration for you.

```python
OBO = Namespace("http://purl.obolibrary.org/obo/")
with GraphContext(g, {"ex": ex, "obo": OBO}):
    person = Class(ex.Person)
    
    #Get a handle on the IAO definition annotation property, declaring it if necessary
    definition_annotation = Property(OBO.IAO_0000115).declare_annotation_property(OBO.IAO_0000115)

    # Annotate the person class with the definition annotation, using the handle
    person.set_annotation(definition_annotation, "A human being.")
```
---

## 3. Lifecycle: Merging and Imports

For the engineering rationale behind these practices, see the ontology-engineering lifecycle guide (listed in that skill's routing).

### **Merging with ROBOT**
When combining multiple ontologies, always prefer **ROBOT merge** over `rdflib` concatenation. ROBOT handles import resolution and semantic consistency correctly.

```bash
robot merge --input A.owl --input B.owl --output out.owl
```

### **Import Resolution**
*   **ROBOT/Java OWL API:** Automatically resolves imports using local `catalog-v001.xml` or `catalog.xml` files found in the ontology directory.
*   **rdflib:** Does **not** resolve catalog-based imports. Concatenating files with `rdflib` often results in profile violations like `multiple_labels`.

---

## 4. Verification Checklist

After construction, always run the following validation sequence:

1.  **`check-ontology`**: Catch OWL syntax and profile (OWL 2 DL) violations.
2.  **`ontology-measure-essentials`**: Generate a report of essential measures: the number of classes, individuals and properties, axiom counts, the OWL profiles, etc.