# CNL Configuration

This guide covers how CNL rendering is configured via ontology-embedded `OWL_DSL_*` annotations, an optional YAML file, and how the two sources combine.
The preferred approach is to use ontology-embedded annotations.

## 1. Unified Resolution

All review and reasoning entry points share one resolver:

```python
from owl_dsl.annotations import resolve_definition_properties

definition_properties, annotation_graph = resolve_definition_properties(
    handler, onto, owl_url_or_path, configuration_file, verbose
)
```

*   **YAML first:** When `configuration_file` is given, `setup_configuration_from_yaml()` is applied to the handler.
*   **Annotations always:** The annotation graph is then loaded and `apply_annotations_to_handler()` is applied on top.
*   **Result:** Phrasing templates, ignore lists, and reflexive roles accumulate from both sources.
*   **Precedence:** `expert_definition_properties` from `OWL_DSL_000005` take precedence. When the ontology declares them, they win; otherwise the YAML value is kept (or annotation defaults when no file was given).

Prefer `resolve_definition_properties` for new code. `setup_configuration()` in `cli.py` is a backwards-compatible wrapper around `setup_configuration_from_yaml()`.

---

## 2. OWL_DSL_* Annotations (Preferred)

Embed CNL configuration directly in the ontology so it stays self-documenting and portable. The annotation properties live in the namespace `http://purl.org/ontology-dsl#`.  Use these
to annotate classes and properties:

| Annotation | Purpose |
| :--- | :--- |
| `OWL_DSL_000001` | Singular predicate string template (e.g., `"is a part of {}"`) |
| `OWL_DSL_000002` | Plural predicate string template (e.g., `"has {} as parts"`) |
| `OWL_DSL_000003` | Prompt phrase using the predicate to request a definition (e.g., `"What is a part of {}?"`) |
| `OWL_DSL_000004` | Class inferences to ignore (an RDF collection of class IRIs, set on the `owl:Ontology` node) |
| `OWL_DSL_000005` | Expert definition properties (e.g., `IAO_0000115`, set on the `owl:Ontology` node) |
| `OWL_DSL_000006` | Standard role restriction "is" phrasing — marks properties whose CNL template derives as `"is <label> {}"` |
| `OWL_DSL_000007` | Reflexive roles — custom phrasing for reflexive property restrictions (e.g., `"that is a part of itself"`) |

Set property templates on the property IRI and global settings (`OWL_DSL_000004`, `OWL_DSL_000005`) on the `owl:Ontology` node. See [Ontology Development Guide](ontology-development.md) for how to add these via InfixOWL `set_annotation()` or plain `rdflib`.

---

## 3. YAML Configuration File (Supplement)

Use an external YAML file for rapid prototyping or when annotations are not yet available. A sample config for OBO ontologies ships as `ontology_configurations/OBO.CNL.yaml`.

```yaml
tooling:
  expert_definition_properties: ['http://purl.obolibrary.org/obo/IAO_0000115']

class_inference_to_ignore: ['material entity', 'anatomical entity', 'process']

role_restriction_phrasing:
  http://example.org/hasPart:
    - "has {} as part"
    - "have {} as part"
    - "What has {} as part?"

standard_role_restriction_is_phrasing:
  - http://example.org/connectedTo

role_restriction_wo_articles:
  - http://example.org/locatedIn

reflexive_roles:
  - http://example.org/contains: ["itself"]
```

*   `tooling.expert_definition_properties`: Definition annotation IRIs for textual definitions.
*   `class_inference_to_ignore`: Class labels skipped when navigating entailed axioms.
*   `role_restriction_phrasing`: Per-property `(singular, plural, prompt)` templates.
*   `standard_role_restriction_is_phrasing`: Properties rendered as `"is <label> {}"`.
*   `role_restriction_wo_articles`: Properties rendered without articles.
*   `reflexive_roles`: Custom reflexive phrasing per property.

---

## 4. Tool Wiring

*   **`configurationFile` is optional** on `verbalize-ontology-class`, `find-ontology-property`, and `class-entailments`. Omit it when the ontology carries `OWL_DSL_*` annotations.
*   **Auto-discovery:** When omitted, the wrapper looks for `<stem>.cnl.yaml` (also `.CNL.yaml`, `.cnl.yml`) next to the OWL file and passes it as `--configuration-file` only when found. Absence is valid.
*   **Review backend:** `owl_dsl.review` loads via `pyhornedowl.open_ontology(owl_url_or_path)` directly. `--sqlite-file` is only needed for the `destroy_sqlite` action.
*   **Reasoning backend:** `owl_dsl.reason` (`class-entailments`) still uses the SQLite/ELK path, but its `--configuration-file` is also optional with the same annotation-first precedence.
*   **Rendering flags:** `verbalize-ontology-class` exposes `collectDefinitionInfo`, `fullDefinition`, and `noTextualDefinition`, mapping to `--collect-definition-info / --no-collect-definition-info`, `--full-definition / --no-full-definition`, and `--no-textual-definition`. Omit them to use CLI defaults (on, on, off).

---

## 5. Renderer capabilities (Manchester OWL -> CNL)

The OWL_DSL's `CNLRenderer` transforms OWL class expressions into a readable, Manchester-inspired controlled natural language rather than OWL's normative `RDF/XML` or functional syntax.

### Manchester coverage

| Feature | CNL Example |
| :--- | :--- |
| **SubClassOf/EquivalentTo** | `a Person that has Heart as part` |
| **And/Or/Not** | `a Person that is not a Vegetarian` |
| **Cardinality** | `is related to at least 2 Persons` |
| **hasValue** | `has status Active` |
| **Self** | `that is a part of itself` |

*   **Class expression elements:** Supports `SubClassOf`, `EquivalentTo`, `IntersectionOf`, `UnionOf`, `ComplementOf`, `ObjectSomeValuesFrom`, `ObjectOnlyValuesFrom`, `ObjectExactCardinality`, `ObjectMinCardinality`, `ObjectMaxCardinality`, `ObjectHasValue`, `DataSomeValuesFrom`, `DataOnlyValuesFrom`, `DataExactCardinality`, `DataMinCardinality`, `DataMaxCardinality`, and `Self`.

### Lexical and performance

*   **SKOS label support** — prefers `skos:prefLabel` over `rdfs:label` to prioritize formal descriptors. It can also leverage `skos:altLabel` for more natural phrasing in CNL.
*   **Concept vs. Class distinction** — Supports differentiating between formal `OWL` axioms (for class definitions) and informal `SKOS` concepts (for taxonomic labels) to ensure appropriate CNL tone.
*   **String/literal rendering** — handles `str`, `int`, `float`, `bool`, and `Thing` instances
*   **Indefinite articles** — `prefix_with_indefinite_article` uses lazy spaCy loading + `@lru_cache` for deterministic `a`/`an`
*   **Entity caching** — `_get_entity_by_iri()` with an LRU cache for repeated lookups
*   **Def info env var** — `OWL_DSL_COLLECT_DEFINITION_INFO` (default `1`) to skip definition tracking for performance

Verify: run `verbalize-ontology-class` on a some/only/min restriction and confirm CNL contains `that`, `only`, or `at least`.

