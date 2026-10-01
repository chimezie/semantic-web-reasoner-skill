
# /// script
# requires-python = ">=3.11"
# dependencies = ["rdflib"]
# ///
"""
get-annotation.py — Get annotation values on an OWL entity

Positional arguments:
1. OWL file path
2. Base URI (namespace base URI, ending with # or /)
3. Class/property reference (local name or rdfs:label)
4. "true" if classReference is a local name, "false" if it's an rdfs:label
5. Annotation property URI or CURIE
"""
import sys
from rdflib import Graph, RDFS, Literal, URIRef, Namespace

SKOS_NS = Namespace("http://www.w3.org/2004/02/skos/core#")
DC_NS = Namespace("http://purl.org/dc/elements/1.1/")
OBO_NS = Namespace("http://purl.obolibrary.org/obo/")
IAO_NS = Namespace("http://purl.obolibrary.org/obo/IAO_")

COMMON_NS_BINDINGS = {
    'skos': SKOS_NS,
    'dc': DC_NS,
    'obo': OBO_NS,
    'iao': IAO_NS
}


def resolve_annotation_property(g, raw: str) -> URIRef:
    if "://" in raw:
        return URIRef(raw)
    try:
        return g.namespace_manager.expand_curie(raw)
    except ValueError:
        pass
    return URIRef(raw)


def main():
    owl_file = sys.argv[1]
    baseuri = sys.argv[2]
    class_reference = sys.argv[3]
    by_id = sys.argv[4].lower() == "true" if len(sys.argv) > 4 else False
    annotation_property = sys.argv[5]

    g = Graph()
    g.parse(owl_file, format="xml")
    for prefix, ns in COMMON_NS_BINDINGS.items():
        g.bind(prefix, ns)

    if by_id:
        entity_iri = URIRef(baseuri + class_reference)
    else:
        matches = list(g.subjects(RDFS.label, Literal(class_reference)))
        if not matches:
            print(f"ERROR: No entity found with rdfs:label '{class_reference}'")
            sys.exit(1)
        entity_iri = matches[0]

    annotation_url = resolve_annotation_property(g, annotation_property)

    values = [f"'{str(o)}'" for o in g.objects(entity_iri, annotation_url)]

    if values:
        print(f"Values for '{annotation_property}' on '{str(entity_iri)}' are {', '.join(values)}")
    else:
        print(f"There are no values for '{annotation_property}' on '{str(entity_iri)}'")


if __name__ == "__main__":
    main()
