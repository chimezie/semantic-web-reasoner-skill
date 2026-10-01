# FuXi CLI

Use the FuXi CLI to perform forward chaining, BFP queries, and OWL to DLP transformations.

## Prereqs
- [Apache Jena `riot`](https://jena.apache.org/documentation/io/) (for serialization/cleaning)
- [Graphviz `dot`](https://graphviz.org/) (for `*-svg/png` output)

## Core Subcommands
Run each via `fuxi.<cmd> --help`:
- `fuxi.core`: Forward chaining inference.
- `fuxi.proof`: BFP (Backward-Forward Proof) queries and proof rendering.
- `fuxi.owl`: OWL to DLP transformation and Manchester OWL rendering.

### Common Flags
| Flag | Description |
| :--- | :--- |
| `--rules PATH` | Path to an N3 rules file (repeatable). |
| `--output FORMAT` | `n3`, `ttl`, `nt`, `xml`, `TriX` (case-sensitive), `conflict`, `rif`, `rif-xml`, `man-owl`, `adornment`, `pml`, `proof-graph-svg/png`, `rete-network-svg/png`, `sip-collection-svg/png`. |
| `--ns PREFIX=URI` | Namespace prefix mapping (repeatable). |
| `--input-format FMT` | `xml`, `trix` (lowercase), `n3`, `nt`, `rdfa` (default: `xml`; use `n3` for `.ttl` Turtle files). |
| `--ontology-format FMT` | Same choices as `--input-format` (default: `xml`; use `n3` for `.ttl` files). |
| `--ontology PATH` | OWL graph for DLP rule extraction (repeatable). |
| `--dlp` | Use DLP to extract rules from OWL/RDF. |
| `--hybrid` | Identify predicates that are both derived and base. |
| `--edb QNAME` | Designate a predicate as base (repeatable). |
| `--idb QNAME` | Designate a predicate as derived (repeatable). |
| `--hybrid-predicate QNAME` | Explicitly specify a hybrid predicate (repeatable). |
| `--stdin` | Parse STDIN as an RDF graph. |
| `--closure` | Serialize inferred triples along with original triples. |
| `--why SPARQL` | SPARQL query for BFP (required on `fuxi.proof`, optional on `fuxi.owl`, rejected on `fuxi.core`). |
| `--method {bfp,naive}` | Reasoning method (`fuxi.proof` always uses `bfp`; `fuxi.owl --why` requires `--method=bfp`). |
| `--first-answer` | Stop after first solution with `--why` (`fuxi.proof`, `fuxi.owl`). |
| `--class QNAME` | Target class for `--output=man-owl` (repeatable, `fuxi.owl` only). |
| `--property QNAME` | Target property for `--output=man-owl` (repeatable, `fuxi.owl` only). |
| `--normalize` | Check Rector-style normalization (requires `--output=man-owl`, `fuxi.owl` only). |

---

## 1. Forward Chaining with `fuxi.core`

Run DLP over an OWL TBox plus instance data and serialize just the inferred facts:

```bash
fuxi.core --dlp \
  --ns ex=http://example.org/ \
  --ontology ontology.ttl --ontology-format n3 \
  --input-format n3 \
  --output n3 facts.ttl > inferred.n3
```

Add `--closure` to include original triples in the output.

## 2. Proof Queries with `fuxi.proof`

`fuxi.proof` answers a SPARQL query using backward chaining. `--why` is required.

Preferred form with explicit `PREFIX` (portable to plain `rdflib` and remote endpoints):

```bash
fuxi.proof --dlp \
  --ns ex=http://example.org/ \
  --input-format n3 \
  --why "PREFIX ex: <http://example.org/> SELECT ?s ?o WHERE { ?s ex:relatedTo ?o }" \
  facts.ttl > answers.txt
```

A shorthand use of `--ns` (goal extraction and BFP query translation resolve `ex:` via `--ns`, so the `PREFIX` prologue can be omitted):

```bash
fuxi.proof --dlp \
  --ns ex=http://example.org/ \
  --input-format n3 \
  --why "SELECT ?s ?o WHERE { ?s ex:relatedTo ?o }" \
  facts.ttl > answers.txt
```

Disclaimer: the shorthand works on the FuXi CLI but fails on plain
`rdflib` (`Graph.query` without `initNs`) and on most remote SPARQL endpoints,
which require an explicit `PREFIX` prologue. Use the explicit-`PREFIX` form for
any query you intend to reuse outside `fuxi.proof` / `fuxi.owl --why`.

Add `--first-answer` to stop after the first solution. Use `--output proof-graph-svg` for visual proofs.

## 3. OWL Operations with `fuxi.owl`

Run DLP reasoning over an ontology and serialize inferred facts:    

```bash
fuxi.owl --dlp --output n3 ontology.owl > inferred.n3
```

Render selected classes in Manchester OWL syntax (requires `--ns`):

```bash
fuxi.owl --dlp \
  --ns ex=http://example.org/ \
  --class ex:Person \
  --output man-owl ontology.owl
```

Check Rector-style normalization (warnings go to stderr; `--normalize` only takes
effect with `--output=man-owl` and no `--class`/`--property`):

```bash
fuxi.owl --normalize --output man-owl ontology.owl
```

## 4. Pipe Patterns with `riot`

Use Jena `riot` to convert or clean data. Ensure `JAVA_HOME` is set.

**Convert `fuxi.core` XML to Turtle:**

```bash
fuxi.core --dlp --input-format n3 --output xml facts.ttl \
  | riot --syntax=rdfxml --formatted=ttl - > inferred.ttl
```

**Clean N-Quads with encoding issues:**

```bash
riot --syntax=nquads --output=nquads input.nq 2>/dev/null > clean.nq
```

## 5. Chaining via `--stdin`

Any subcommand accepting `--stdin` can consume the output of a previous stage.

```bash
fuxi.core --dlp --input-format n3 --output n3 facts.ttl \
  | fuxi.owl --stdin --input-format n3 \
    --ns ex=http://example.org/ \
    --dlp --output man-owl --class ex:Person > person.manowl
```

*Note: Ensure `--ns` and `--dlp` are repeated in downstream stages so QNames and rules resolve.*

## 6. Bulk Data: TSV → TTL Pipelines

Generate Turtle from large gzipped TSV dumps without materializing intermediate files:

```bash
# Example: Stream-convert a TSV file to Turtle
PREFIXES='@prefix imdb: <https://www.imdb.com/> . @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> . '
(
  echo "${PREFIXES}"
  gunzip -c data.tsv.gz \
    | sed 1d \
    | awk -F'\t' '$3 != "\\N" {
        gsub(/\\/, "\\\\", $3); gsub(/"/, "\\\"", $3)
        if ($4 == "\\N") printf "imdb:%s imdb:title \"%s\" .\n", $1, $3
        else printf "imdb:%s imdb:title \"%s\" ; imdb:year %s .\n", $1, $3, $4
      }'
) > titles.ttl
```

*Note: The `\N` guard prevents illegal Turtle escapes that would cause `riot` to fail.*

Validate the generated TTL:

```bash
riot --syntax=turtle --count titles.ttl
```

---

## Troubleshooting

| Issue | Fix |
| :--- | :--- |
| `KeyError: 'prefix'` in `fuxi.owl` | Add `--ns prefix=uri` for all prefixes used in `--class`/`--property`. |
| `fuxi.core` does not support `--why` | Use `fuxi.proof` for BFP queries. |
| `man-owl` requires `fuxi.owl` | Command must be `fuxi.owl`. |
| `proof-graph` requires `--why` | Add `--why "<SPARQL>"` and `--method=bfp`. |
| Empty output with `--dlp` | Ensure `--ontology` is provided or facts contain the TBox. |
| `riot` rejects file | Check for illegal escapes (e.g. `"\N"`) or use `riot --count` to debug. |
