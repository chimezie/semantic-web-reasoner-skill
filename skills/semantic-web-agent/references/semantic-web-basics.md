# Semantic Web Basics

Foundational concepts for working with RDF, OWL, Knowledge Graphs, and Linked Data Web architecture.

## 1. Identifiers and Namespaces

In the Semantic Web, everything is identified by a URI.

### **Base URIs and Local Names**
*   **Base URI (or Namespace URI):** A common prefix for related URIs. Usually ends in `/` or `#`.
*   **Local Name:** The part of the URI following the base URI.
*   **QNames / Curies:** Shorthand for a full URI using a prefix (e.g., `ex:Person`).

### **Naming Conventions & Design**
*   **Unambiguity**: Distinguish between the **resource** (the thing/concept) and the **document** (the representation). Never use a document URL (e.g., `.../person.html`) as an identifier for a real-world object.
*   **Stability**: Local names should be stable and mnemonic. Do not encode labels or versions in term IRIs (e.g., use `ex:Person` not `ex:Person_v1`).
*   **Dereferenceability**: Namespace/base URIs should be resolvable over HTTP to provide the "authoritative" description of their terms.
*   **Tool Argument Conventions**:
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

## 3. Linked Data Principles (4 Rules)

Implementation is guided by four expectations of behavior:
1.  **Use URIs as names for things**: Identify entities via URIs.
2.  **Use HTTP URIs**: Enables name lookup by users and machines.
3.  **Provide useful information via standards**: When a URI is looked up, provide info using data representation standards like RDF, RDFS, and OWL.
4.  **Include links to other URIs**: Connect individual datasets (and their ontologies) into an unbounded web.

## 4. URI Design & Publishing (Cool URIs)

To ensure identifiers are "Cool" (simple, stable, and manageable), follow these patterns:

### **Hash vs. 303 Decision**
| Scheme | Best For | Pros | Cons | Example |
| :--- | :--- | :--- | :--- | :--- |
| **Hash URIs** | Vocabularies, OWL Ontologies | Low latency; single request for all terms | Overfetches all data in the document | `.../about#Person` |
| **303 URIs** | Instance Data, Large sets | Granular access; flexible redirection | More HTTP round-trips (latency) | `.../id/person/123` |
| **Combined** | Large Scale / Hybrid | Balance of granularity and speed | Slightly more complex setup | `.../bob#this` |

### **Cool URI Checklist**
- [ ] **Simple**: Short, mnemonic URIs.
- [ ] **Stable**: Avoid implementation-specific bits (no `.php`, `.asp`, `.jsp`).
- [ ] **Manageable**: Use a dedicated subdomain for IDs (e.g., `id.example.org`) and include the year in the path for versioned schema evolution.
- [ ] **Persistent**: Leverage PURLs or other redirection services.
- [ ] **Minted**: Prefer minted HTTP URIs over blank nodes or "reference by description" via IFPs (like `foaf:mbox`).

## 5. Dereferencing & Content Negotiation

Linked Data relies on **REST** to allow resources to be discovered via HTTP.

### **"Follow Your Nose"**
To "dereference" a URI means to perform an HTTP GET request to retrieve its representation. 
- **Authoritative**: Information from the same domain as the URI is considered authoritative.
- **303 See Other**: For abstract concepts (non-info resources), the server returns `HTTP 303` to redirect the client to the describing document.
- **Hash Behavior**: For hash URIs, the fragment is stripped by the client; the server returns the document containing the term.

### **Content Negotiation**
Clients use the `Accept` header to request specific media types (e.g., `text/turtle`, `application/rdf+xml`).
- **Mixed Clients**: Servers use `q-values` (standard HTTP parameters) to decide whether to serve HTML (for humans) or RDF (for agents).
- **Variant Quality**: If the HTML is just a table of the structured data, serve RDF. If the HTML is a rich article and RDF is minimal, serve HTML.
- **Large Datasets**: For massive instance data, provide a **SPARQL endpoint** instead of forcing bulk 303 downloads.

## 6. Linking Patterns

### **Predicate Selection**
Use specific predicates to describe the relationship between a resource and its representations:

| Predicate | Usage | Note |
| :--- | :--- | :--- |
| `rdfs:seeAlso` | Related info | General link; no format guarantee. |
| `rdfs:isDefinedBy` | Authoritative def | Subproperty of `seeAlso`; points to the schema doc. |
| `wdrs:describedby` | Instance description | Useful for 303-less "toucan" publishing. |
| `foaf:page` | Human-readable doc | Links thing to its HTML page. |
| `foaf:homepage` | Personal homepage | Inverse functional property (IFP). |
| `xhv:prev` / `next` | Navigation | Pagination in list output. |
| `dc:format` | Format hint | Declares if a linked doc is PDF, RDF, etc. |
| `xtypes` | RDF type hint | e.g., `rdf:type xtypes:Document-RDFSerialisation`. |

### **Linking Self-Descriptions**
A "Linked Data" client should be able to inspect a link and decide if it wants to follow it based on:
- **Significance/Authority**: Use `rdfs:isDefinedBy` for the primary source.
- **Syntax/Format**: Use `dc:format` or `xtypes`.
- **Vocabulary**: Declare which vocabulary is used.
- **Size**: Provide hints to avoid downloading MiB-scale files.

### **Linking All URIs**
For every real-world object, link the Identifier $\leftrightarrow$ RDF Doc $\leftrightarrow$ HTML Doc:
- In RDF: `<resource> foaf:page <html-doc> ; rdfs:isDefinedBy <rdf-doc> .`
- In HTML: Use `<link rel="alternate" type="application/rdf+xml" href="...rdf">` (or `rel="meta"` if the RDF is *about* the page).
- Header: Use the `Content-Location` header in responses.

## 7. Verification Checklist

Use these commands to verify your Linked Data publishing:

```bash
# Check for 303 redirect for a resource identifier
curl -sI -H "Accept: text/turtle" <resource-IRI> | grep "303 See Other"

# Check for 200 OK for the describing document
curl -sI <rdf-document-URI> | grep "200 OK"

# Verify hash URI (fragment stripped)
curl -sI <hash-base-URI> | grep "200 OK"

# Check if the ontology documents the resource
grep -C 2 "rdfs:isDefinedBy" <ontology-file>
```

## 8. Core Vocabularies

Whenever possible, reuse standardized vocabularies to ensure interoperability:

*   **[SKOS](https://www.w3.org/TR/skos-reference/):** For taxonomies and concept schemes.
*   **[OBO IAO](https://obofoundry.org/ontology/iao.html):** For ontology annotations and metadata.
*   **[Relation Ontology (RO)](https://obofoundry.org/ontology/ro.html):** For object properties and relations.
*   **[FOAF](https://xmlns.com/foaf/spec/):** For describing people, social relationships, and linking (`foaf:page`, `foaf:homepage`).
*   **[DCMI Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/):** For basic metadata (`dc:format`, creator, date).
*   **[The Creative Commons Rights Expression Language](https://opensource.creativecommons.org/ccrel/):** For licensing and copyright.
*   **[Time Ontology in OWL](https://www.w3.org/TR/owl-time/):** For temporal properties.
*   **[vCard Ontology](https://www.w3.org/TR/vcard-rdf/):** For people and organisations.
*   **[PROV Ontology](https://www.w3.org/TR/prov-o/):** For provenance.
