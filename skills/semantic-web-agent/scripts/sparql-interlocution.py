
# /// script
# requires-python = ">=3.11"
# dependencies = ["rdflib", "fuxi"]
# ///
"""
sparql-interlocution.py — Execute SPARQL queries with OWL entailment via FuXi's sparql_interlocution_basic_graph_pattern

Positional arguments:
1. SPARQL endpoint URL
2. nsBindings (JSON: {"prefix": "uri", ...})
3. SPARQL query string
4. Path to OWL file for TBox (ontology), or "--" for none
5. Path to N3 rules file, or "--" for none

The entailing store is built exactly the way fuxi_sparql_writeup.py builds
it: SPARQLPredicatePartitioner over the remote SPARQLServiceGraph (EDB) with
the N3 program as IDB, identify_hybrid_predicates=True, the local TBox graph,
and URIRef-valued namespace maps throughout; the query is then answered by
sparql_interlocution_basic_graph_pattern(query, entailing_graph.store,
generate_proofs=True, ns_bindings=...) so solution bindings thread across
the derived/base join instead of being enumerated unconstrained.
"""
import json
import sys

from fuxi.Horn.HornRules import horn_from_n3
from fuxi.Horn.PositiveConditions import build_uniterm_from_tuple
from fuxi.SPARQL.service import SPARQLServiceGraph
from fuxi.SPARQL.utilities import (
    namespaces_bindings as truth_ns_bindings,
    sparql_interlocution_basic_graph_pattern,
)
from fuxi.predicates import SPARQLPredicatePartitioner
from fuxi.Rete.Proof import TruthMaintenanceGraphSerializer
from rdflib import Graph, URIRef


def rule_head_predicates(rule):
    """Head predicates of a single Horn rule as URIRefs."""
    preds = set()
    head = rule.formula.head
    if hasattr(head, "op"):
        preds.add(URIRef(str(head.op)))
    if hasattr(head, "formulae"):
        for sub in head.formulae:
            if hasattr(sub, "op"):
                preds.add(URIRef(str(sub.op)))
    return preds


def collect_head_predicates(ruleset):
    """Extract all head predicates from a ruleset (N3 or DLP)."""
    preds = set()
    for rule in ruleset:
        preds |= rule_head_predicates(rule)
    return preds


def main():
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    endpoint_url = sys.argv[1]
    ns_bindings = json.loads(sys.argv[2])
    query = sys.argv[3]
    owl_file = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] not in ("", "--") else None
    rules_file = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] not in ("", "--") else None

    # URIRef-valued map, as in the writeup script (plain strings break
    # rule ns_mapping resolution downstream). Truth (bfp/bfl) bindings
    # included so proof rendering resolves the meta-interpreter terms.
    ns_map = {k: URIRef(v) for k, v in ns_bindings.items()}
    ns_map.update(truth_ns_bindings)

    tbox_graph = None
    if owl_file:
        tbox_graph = Graph()
        tbox_graph.parse(owl_file)
        for prefix, uri in ns_map.items():
            tbox_graph.bind(prefix, uri)

    # Remote SPARQL endpoint serves as EDB (instance data).
    fact_graph = SPARQLServiceGraph(endpoint_url)
    if tbox_graph is not None:
        fact_graph.namespace_manager = tbox_graph.namespace_manager
    else:
        ns_graph = Graph()
        for prefix, uri in ns_map.items():
            ns_graph.bind(prefix, uri)
        fact_graph.namespace_manager = ns_graph.namespace_manager

    program = []
    if rules_file:
        with open(rules_file) as f:
            n3_rules = list(horn_from_n3(f))
        for rule in n3_rules:
            rule.ns_mapping.update(ns_map)
        program.extend(n3_rules)

    # Snapshot N3 rule identities BEFORE the partitioner extends the
    # program list in place with TBox DLP rules.
    n3_rule_ids = {id(rule) for rule in program}

    entailment_builder = SPARQLPredicatePartitioner(fact_graph,
                                                    rules=program,
                                                    identify_hybrid_predicates=True,
                                                    tbox_only_graph=tbox_graph)

    # Guard: DLP compilation of the TBox can emit rules headed by base
    # (EDB) predicates (e.g. OWL hasValue restrictions on imdb:type and
    # imdb:role). Those flip plain EDB lookups into recursive
    # backward-chaining goals, which explode over large endpoints (the
    # writeup script avoids this with a hand-built minimal TBox). Drop
    # TBox-sourced rules with EDB heads; explicit N3 bridge rules are
    # always kept, as are TBox rules deriving genuinely new predicates.
    # The derived/hybrid predicate lists (computed pre-filter in the
    # partitioner) are repaired to match, otherwise the store keeps
    # routing the dropped predicates through BFP and hangs anyway.
    edb_predicates = set(entailment_builder.edb_predicates or [])
    dropped_heads = set()
    kept_rules = []
    for rule in entailment_builder.rules:
        heads = rule_head_predicates(rule)
        if id(rule) in n3_rule_ids or not (heads & edb_predicates):
            kept_rules.append(rule)
        else:
            dropped_heads |= {str(h) for h in heads}
    entailment_builder.rules = kept_rules

    def _base(pred):
        s = str(pred)
        return s[:-len("_derived")] if s.endswith("_derived") else s

    entailment_builder.derived_predicates = [
        p for p in (entailment_builder.derived_predicates or [])
        if _base(p) not in dropped_heads
    ]
    entailment_builder.hybrid_predicates = [
        p for p in (entailment_builder.hybrid_predicates or [])
        if str(p) not in dropped_heads
    ]
    entailing_graph = entailment_builder.create_entailing_store(ns_map=ns_map)

    answers, proofs = sparql_interlocution_basic_graph_pattern(
        query, entailing_graph.store, generate_proofs=True, ns_bindings=ns_map)

    # SPARQLResult iteration yields ResultRow tuples (no .vars); use the
    # result-level .vars/.bindings instead. ASK answers come back as bool.
    results = []
    if isinstance(answers, bool):
        results.append({"ask": answers})
    else:
        for binding in answers.bindings:
            out = {}
            for var in answers.vars:
                val = binding.get(var)
                out[str(var)] = val.n3() if hasattr(val, "n3") else str(val)
            results.append(out)
    response = f"# Results #\n{results}"
    for (goal,
         (truth_graph, adorned_program, meta_interp_network, inferred_facts, pf, goal_lit)) in (proofs or {}).items():
        serializer = TruthMaintenanceGraphSerializer(truth_graph, adorned_program, ns_map=ns_map)
        goal_lit = build_uniterm_from_tuple(goal)
        for prefix, uri in ns_map.items():
            goal_lit.ns_manager.bind(prefix, uri)
        response += ("\n= Proof using BFP meta interpreter and compilation of meta rules =\n")
        response += serializer.human_readable_serialize(pf, goal, as_uniterm=goal_lit, ns_bindings=ns_map)
        response += "\n"
        response += serializer.meta_rule_explainer()
    return response

if __name__ == "__main__":
    print(main())
