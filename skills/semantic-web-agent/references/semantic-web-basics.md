# Semantic Web Basics

Foundational concepts for working with RDF and OWL.

## 1. Identifiers and Namespaces

In the Semantic Web, everything is identified by a URI.

### **Base URIs and Local Names**
*   **Base URI (or Namespace URI):** A common prefix for related URIs. Usually ends in `/` or `#`.
*   **Local Name:** The part of the URI following the base URI.
*   **QNames / Curies:** Shorthand for a full URI using a prefix (e.g., `ex:Person`).

### **Naming Conventions**
*   Use a consistent base URI for your ontology.
*   When using tool arguments:
    *   `ontologyUri` must have **no** trailing `#`.
    *   `baseuri` **must** end in `#` or `/`.

## 2. Serialization Formats

The choice of format depends on whether the file contains just data or also logical rules.

| Format | Primary Use Case | Notes |
| :--- | :--- | :--- |
| **OWL/RDF/XML** | Ontology Exchange | Highly compatible with tools like Protégé. |
| **Turtle (.ttl)** | General Data/Ontologies | Human-readable, widely used. |
| **N3 (.n3)** | Rule-based Data | Preferred when using N3/RIF rules for reasoning. |
| **N-Quads (.nq)** | Named Graphs | Used when data is partitioned into multiple graphs. |
| **SPARQL (.rq)** | Queries | Keep SPARQL queries in separate `.rq` files. |

## 3. REST and Dereferencing

Linked Data relies on the **REST** (Representational State Transfer) architectural style to allow resources to be looked up and discovered over HTTP.

### **HTTP Dereferencing**
To "dereference" a URI means to perform an HTTP GET request to retrieve its representation.
1.  **GET Request**: The client sends a `GET` request for a URI.
2.  **303 See Other**: For abstract concepts (non-information resources), the server should return an `HTTP 303 See Other` response. This directs the client to a specific document (the representation) that describes the concept.
3.  **Content Negotiation**: Clients use the `Accept` header to request specific media types (e.g., `text/turtle`, `application/rdf+xml`, `application/ld+json`). The server responds with the best matching representation.

## 4. Linked Data Principles (4 Rules)

Implementation is guided by four expectations of behavior:
1.  **Use URIs as names for things:** Identify entities via the universal URI set.
2.  **Use HTTP URIs:** Enables name lookup by users and machines.
3.  **Provide useful information via standards:** When a URI is looked up, provide info using standards like `RDF` or `SPARQL`.
4.  **Include links to other URIs:** Connect individual datasets into an unbounded web.

## 5. Core Vocabularies

Whenever possible, reuse standardized vocabularies to ensure interoperability:

*   **[SKOS](https://www.w3.org/TR/skos-reference/):** For taxonomies and concept schemes.
*   **[OBO IAO](https://obofoundry.org/ontology/iao.html):** For ontology annotations and metadata.
*   **[Relation Ontology (RO)](https://obofoundry.org/ontology/ro.html):** For object properties and relations.
*   **[FOAF](https://xmlns.com/foaf/spec/):** For describing people and social relationships.
*   **[DCMI Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/):** For basic metadata (creator, date, etc.).
*   **[The Creative Commons Rights Expression Language](https://opensource.creativecommons.org/ccrel/):** For licensing and copyright information.
*   **[Time Ontology in OWL](https://www.w3.org/TR/owl-time/):** For temporal properties of resources.
*   **[vCard Ontology](https://www.w3.org/TR/vcard-rdf/):** For people and organisations.
*   **[PROV Ontology](https://www.w3.org/TR/prov-o/):** For provenance information.
