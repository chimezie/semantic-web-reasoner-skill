# Check Ontology Reference

## Reporting & Inspection

### `check-ontology`

**Report JSON Schema:**
`array of {level, violations:[{<rule_name>:[{subject,...}]}]}`

**ROBOT Rule Names:**
The `select` and `exclude` arguments control which [rules](https://robot.obolibrary.org/report_queries/) are included or excluded, and below are the names of the rules that can be used:

- `duplicate_label` (Two different subjects have been assigned the same label. )
- `missing_definition` ( An entity does not have a definition or elucidation) 
- `missing_superclass` (A class does not have a superclass. This is not relevant for top-level classes, but may reveal orphaned children)
- `missing_label` (An entity does not have a label or the label is empty.)
- `missing_ontology_title` (The ontology header is missing a title)
- `missing_ontology_description` (The ontology header is missing a description)
- `duplicate_definition` (An entity shares an exact definition or elucidation with another entity.)
- `multiple_labels` (An entity has more than one label)
- `multiple_definitions` (An entity has more than one definition or elucidation)
- `annotation_whitespace` (An annotation has leading or trailing whitespace)
- `deprecated_class_reference` (A deprecated class is used in a logical axiom)

## Database Semantics (`ontology_db.json`)
`create-ontology` stores SQLite files and an index in `workingDir`. The index is a file named `ontology_db.json`.
* **`sqlite_file`**: Path to the SQLite file.
* **`owl_file`**: Source OWL file path.
* **`ontology_base_uri`**: Common prefix for all URIs.
* **`ontology_uri`**: The ontology URI.

When using reasoner tools, ensure you pass the same `workingDir` used during creation.

**Note on Profile Violations**: If `ontology-measure-essentials` reports `owl2dl_profile_violation > 0`, the offending entities are listed. These violations may originate in **imported** ontologies; check `valid_imports` and re-run `validate-profile` to attribute.

