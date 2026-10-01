# FuXi SPARQL Entailment

This guide covers how to perform SPARQL queries over an RDF graph (and/or Horn rules) using FuXi's entailment regime support using a vocabulary governed by an OWL 2 ontology that specifies the semantics.

## 1. The Two Primary Query APIs

FuXi provides two ways to interact with an entailing graph. Both return standard `rdflib.Result` objects.

### **`entailing_graph.query(...)`**
*   **Type:** General Purpose.
*   **Supported:** `SELECT`, `ASK`, `CONSTRUCT`, `DESCRIBE`.
*   **Mechanism:** Dispatches to `TopDownSPARQLEntailingStore.solve_triple_pattern`, which partitions the Basic Graph Pattern (BGP) into EDB (base) and IDB (derived) groups and evaluates them **independently**.
*   **Limitation:** It does **not** pass solution bindings between patterns in a BGP. Use this for simple queries that do not need to join derived and base predicates.

### **`sparql_interlocution_basic_graph_pattern(query, store)`**
*   **Type:** Specialized (SELECT and ASK).
*   **Supported:** `SELECT` (specifically for BGPs that must **join** EDB and IDB patterns) and `ASK`.
*   **Mechanism:** Drives a conjunctive SIP join (`batch_unify`) that pass solution bindings forward through the patterns.
*   **When to use:** Use this when a `SELECT` query joins a derived predicate (e.g., `ex:ancestorOf`) with a base predicate (e.g., `ex:parentOf`).
*   **Note:** `CONSTRUCT` and `DESCRIBE` will raise a `NotImplementedError` using this helper.

---

## 2. Understanding Predicates: EDB vs. IDB

When working with entailment, every predicate is categorized:

*   **Base Predicates (EDB):** Data residing directly in the SPARQL endpoint. They are never derived by rules. (e.g., `imdb:role`, `imdb:person`).
*   **Derived Predicates (IDB):** Predicates that the reasoner must prove via backward-chaining (DLP + N3 rules). (e.g., `ex:Movie`, `ex:acted_in`).

A predicate that is both is a _hybrid_ predicate.

### **Auto-Discovery (Recommended)**
If you do not provide a value for the `derived_predicates` keyword argument of `owl_entailment_regime_graph()`, it will automatically identify them by scanning all rule heads (or consequents) in your program.
Similarly, if you don't provide a value for the `hybrid_predicates` keyword argument, they will be automatically identified.

### **Manual Override**
If you need to restrict the set, provide the specific URIs:
```python
entailing_graph, _ = owl_entailment_regime_graph(
    remote_graph,
    ns_map=ns_map,
    derived_predicates=[EX.Movie, EX.film_director],
    extra_rulesets=program,
)
```

---

## 3. Entailment Regime Mapping

FuXi's entailment support implements a subset of W3C SPARQL 1.1 Entailment Regimes, primarily focused on **Description Logic Programming (DLP)**.

| W3C Regime | FuXi / Rule-based Mapping | Implementation Detail |
| :--- | :--- | :--- |
| **RDF / RDFS** | Simple Entailment | Standard triple matching. |
| **OWL 2 RDF-Based Semantics** | DLP (using N3/RIF rules) | Translates OWL axioms into Horn rules. |
| **RIF Core** | RIF-RDF Interop | Maintains correspondence between RIF frames and RDF triples. |
| **OWL 2 RL** | Optimized DLP | Uses efficient, polynomial-time rule-based reasoning. |

**Key Note on OWL 2 RL & RIF**:
OWL 2 RL is specifically designed to be implemented using rule-based technologies. It can be translated into a specialized **RIF Core** rule set, which is more scalable in practice than a direct translation. FuXi leverages this by allowing the use of N3/RIF rules to drive entailment over the RDF graph.

---

## 4. Entailment Regime Queries

### **Remote SPARQL Endpoint + Local TBox (Recommended)**
When instance data is large and resides behind a remote SPARQL endpoint (e.g., QLever, Virtuoso), load the TBox (ontology) locally to perform Description Logic Programming (DLP) compilation, assuming it is in the OWL 2 RL profile.

You should use the `SPARQLPredicatePartitioner` class to setup entailment against the SPARQL endpoint, returning an entailing graph (via its `create_entailing_store` method) that abstracts querying and entailment over the SPARQL service.

Note that if the SPARQL dataset includes hybrid predicates, you should pass `identify_hybrid_predicates = True` while creating an instance of this class. 

```python
from fuxi.predicates import SPARQLPredicatePartitioner
from fuxi.SPARQL.service import SPARQLServiceGraph
from fuxi.SPARQL.utilities import (
    sparql_interlocution_basic_graph_pattern,
    owl_entailment_regime_graph,
)
from rdflib import Graph, Namespace
from io import StringIO
from fuxi.Horn.HornRules import horn_from_n3

IMDB = Namespace("https://www.imdb.com/")
NS_BINDINGS = {"imdb": IMDB}

# 1. Load the TBox locally for DLP compilation
tbox_graph = Graph()
tbox_graph.parse("imdb.owl")
for prefix, uri in NS_BINDINGS.items():
    tbox_graph.bind(prefix, uri)

# 2. Parse N3 rules (if any) - parsed from string in this case
RULES = """
@prefix imdb: <https://www.imdb.com/> .
{ ?movie     imdb:principal ?principal .
  ?principal imdb:role      "director" ;
             imdb:person    ?person  } => { ?movie imdb:film_director ?person } .
"""
program = list(horn_from_n3(StringIO(RULES)))
for rule in program:
    rule.ns_mapping.update(NS_BINDINGS)

# 3. Create the entailing graph
sparql_graph = SPARQLServiceGraph("http://localhost:7000")
sparql_graph.namespace_manager = tbox_graph.namespace_manager
entailment_builder = SPARQLPredicatePartitioner(
    sparql_graph,
    rules = program,
    identify_hybrid_predicates = True,
    tbox_only_graph = tbox_graph,
)
entailing_graph = entailment_builder.create_entailing_store(ns_map=NS_BINDINGS)

# 4. Execute query, returning an instance of rdflib.plugins.sparql.processor.SPARQLResult.
# Declare the prefixes the query uses inline (or rely on the ns_map above).
query = (
    "PREFIX imdb: <https://www.imdb.com/> "
    "SELECT ?movie ?director WHERE { ?movie imdb:film_director ?director }"
)
result = sparql_interlocution_basic_graph_pattern(query, entailing_graph.store)
# Optionally capture proofs:
# result, proofs = sparql_interlocution_basic_graph_pattern(
#     query, entailing_graph.store, generate_proofs=True, ns_bindings=NS_BINDINGS
# )
```

### **Local Graph (All-in-Memory)**
For smaller datasets, you can do everything in-memory via `owl_entailment_regime_graph` and the fact graph.

```python
fact_graph = Graph().parse("ontology.ttl")
entailing_graph, _ = owl_entailment_regime_graph(fact_graph, ns_map={})

for row in entailing_graph.query("SELECT ..."):
    print(row)
```

Verify: run a `SELECT` joining a derived predicate with a base predicate via `sparql_interlocution_basic_graph_pattern` and confirm bindings flow across the join.
