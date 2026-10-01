
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
"""
import json
import sys
from io import StringIO
from pathlib import Path

from fuxi.Horn.HornRules import horn_from_n3
from fuxi.Horn.PositiveConditions import build_uniterm_from_tuple
from fuxi.SPARQL.service import SPARQLServiceGraph
from fuxi.SPARQL.utilities import (
    owl_entailment_regime_graph,
    sparql_interlocution_basic_graph_pattern,
)
from fuxi.predicates import SPARQLPredicatePartitioner
from fuxi.Rete.Proof import TruthMaintenanceGraphSerializer
from rdflib import Graph, URIRef


def collect_head_predicates(ruleset):
    """Extract all head predicates from a ruleset (N3 or DLP)."""
    preds = set()
    for rule in ruleset:
        head = rule.formula.head
        if hasattr(head, "op"):
            preds.add(URIRef(str(head.op)))
        if hasattr(head, "formulae"):
            for sub in head.formulae:
                if hasattr(sub, "op"):
                    preds.add(URIRef(str(sub.op)))
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

    ns_map = {k: URIRef(v) for k, v in ns_bindings.items()}

    tbox_graph = None
    if owl_file:
        tbox_graph = Graph()
        tbox_graph.parse(owl_file)
        for prefix, uri in ns_bindings.items():
            tbox_graph.bind(prefix, URIRef(uri))

    fact_graph = SPARQLServiceGraph(endpoint_url)
    ns_graph = Graph()
    for prefix, uri in ns_bindings.items():
        ns_graph.bind(prefix, URIRef(uri))
    fact_graph.namespace_manager = ns_graph.namespace_manager

    program = []
    if rules_file:
        n3_rules = list(horn_from_n3(StringIO(Path(rules_file).read_text())))
        for rule in n3_rules:
            rule.ns_mapping.update(ns_bindings)
        program.extend(n3_rules)

    entailment_builder = SPARQLPredicatePartitioner(fact_graph,
                                                    rules = program,
                                                    identify_hybrid_predicates = True,
                                                    tbox_only_graph = tbox_graph)
    entailing_graph = entailment_builder.create_entailing_store(ns_map=ns_map)

    answers, proofs = sparql_interlocution_basic_graph_pattern(query, entailing_graph.store, generate_proofs=True)
    results = []
    for row in answers:
        out = {}
        for var in row.vars:
            val = row[var]
            out[str(var)] = val.n3() if hasattr(val, "n3") else str(val)
        results.append(out)
    response = f"# Results #\n{results}"
    for (goal,
         (truth_graph, adorned_program, meta_interp_network, inferred_facts, pf, goal_lit)) in proofs.items():
        serializer = TruthMaintenanceGraphSerializer(truth_graph, adorned_program, ns_map=ns_map)
        goal_lit = build_uniterm_from_tuple(goal)
        for prefix, uri in ns_bindings.items():
            goal_lit.ns_manager.bind(prefix, uri)
        response += ("\n= Proof using BFP meta interpreter and compilation of meta rules =\n")
        response += serializer.human_readable_serialize(pf, goal, as_uniterm=goal_lit, ns_bindings=ns_map)
        response += "\n"
        response += serializer.meta_rule_explainer()
    return response

if __name__ == "__main__":
    main()
