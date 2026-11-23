# VegVault Database and Schema Guidance

Apply this guide to SQLite schema files, database assembly code, import scripts, validation scripts, and downstream schema compatibility work.

## Authoritative schema

- `Data/SQL/make_tables.sql` is the executable schema. Create it only with `build_database_schema()` (`R/Functions/Database/`): it runs the file statement by statement in one transaction, stops at the first failed statement, and then checks the database with `validate_database_schema()`, which compares every table, view and index with the file. The database assembly stage (`R/Analyses/03_Database_assembly/`) builds the database this way, and so does the legacy `R/01_Data_processing/00_make_database.R` until that stage replaces it. Tests build it into a temporary file with `build_database_schema()` or `build_database_fixture()`.
- The file has two sections: the tables and the view, with every key and constraint declared in the tables, and then all secondary indexes. A bulk load calls `build_database_schema(sel_objects = "tables")`, loads the rows, and then calls it with `sel_objects = "indexes"`. Keep every `CREATE INDEX` in the second section and use semicolons only to end statements (two test scripts in `tests/` still split the file at every semicolon).
- Links between samples and gridpoint samples are stored once per position (`Positions`, `SamplePosition`, `PositionLink`). The gridpoint stage computes them as targets (see `.ai/analysis-structure.md`); the assembly stage writes them. `AbioticDataReference` is a view that returns them once per sample with the v1.0.0 columns; nothing can be written to it, and `DBI::dbListTables()` lists it with the tables.
- `Data/SQL/database_structure.dbml` is the maintained conceptual diagram and must remain semantically aligned with the executable schema. The test of `build_database_schema()` compares the tables, columns, types, primary keys, `NOT NULL` and references of both files (read with `load_dbml_structure()`), so change them together.
- Website pages under `website/database_structure/` document the public schema and must be updated when released tables, columns, relationships, units, or meanings change.
- The database version record is `database: versions` in `config.yml`; its last entry is the version being built. The compatibility `R/00_Config_file.R` reads it from there for the legacy scripts and the website. A released schema or semantic contract change requires an intentional version/changelog update.

## Bulk load

The assembly stage builds every table in memory and writes the file once, with the writers of `R/Functions/Database/` (design note, section 6, and G2 decision 8). Its targets are declared by `build_database_assembly_targets()` (see `.ai/analysis-structure.md`, "Database assembly stage"):

- Each source is first prepared into the tables of `build_source_table_template()`, which hold natural keys (names and texts) only: `prepare_splot_tables()`, `prepare_bien_plot_tables()`, `prepare_fossilpol_tables()` and `prepare_trait_tables()` (TRY and BIEN traits). They keep the v1.0.0 rules with these corrections: FOSSILPOL samples are named `fossilpol_<Neotoma dataset id>_<level>`, BIEN plots `bien_<plot_id>`, trait datasets `<source>_<n>` numbered by their sorted content, ids are never written in scientific notation (`prepare_id_text()`), only count columns become FOSSILPOL taxa, and taxon rows with an empty name are left out. The fixed values and citations of each source, with their v1.0.0 texts and roles, are in `build: sources` of `config.yml`.
- The gridpoint stage's positions, links and gridpoints enter through `prepare_position_tables()`, which matches every sample with coordinates to its position (and stops on one without) and keeps only the positions that samples use, their links and the gridpoints they reach. `prepare_gridpoint_tables()` makes the gridpoints a source (datasets `geo_<long>_<lat>`, samples `geo_<long>_<lat>_<age>`, the v1.0.0 gridpoint reference on every dataset and sample), and `prepare_abiotic_tables()` attaches the values of one climate or soil variable to the gridpoints of the same rounded coordinates and age; each variable is its own source, so the variable ids follow the order of the build. Climate units and details come from the `variables` table of the producer contracts (`load_abiotic_variables()`); the references of each artefact, the soil label, the general VegVault reference and the authors are in `build` of `config.yml`.
- The taxa are classified as in v1.0.0, with `taxospace` (names matched by the Global Names Verifier, classified in the GBIF Backbone Taxonomy). `prepare_taxon_batches()` puts every taxon name of the sources (`prepare_taxon_names()`) in one of `build: classification: n_batches` batches by a hash of the name, so a batch keeps its names when others are added and each batch can be a cached `{targets}` branch. `classify_taxa()` classifies one batch (it needs internet); it aborts when the check name `build: classification: check_taxon` gets no family, so a batch run during a service failure is never kept, and it leaves out GBIF placeholder species (`<genus> spec`). `prepare_classification_tables()` makes the result the last source: every species, genus and family name becomes a taxon with the `taxospace` reference, and a rank name that is not itself classified gets the ranks above it (the most common, for homonyms) instead of a second online query.
- `build_database_tables()` combines the sources in the order of the build (the order of `build: sources`, each climate artefact by variable in the order of its contract), with the trait unit rules of the trait producer (stage 01's `data_trait_unit_rules`), gives every row its id and resolves every foreign key, and checks every trait value against the unit its rule produces. `build_position_tables()` then gives `Positions`, `SamplePosition` and `PositionLink` their ids, and `build_metadata_tables()` writes `version_control` (the build details on the version being built), `BuildProducers` and `Authors`.
- Ids are assigned in memory by `prepare_table_ids()`: rows sorted by their natural key (text in the C locale) and numbered from 1, so the same inputs give the same ids in every build. Foreign keys are resolved in memory by `prepare_table_foreign_key()`, which stops on a key without a parent. No writer reads a table back from the database.
- `save_vegvault_database()` loads the rows into `<name>_work.sqlite` next to the database (`resolve_database_build_paths()`) with `run_database_load()`: the tables and the view, the `build: pragmas_load` settings of `config.yml`, every table in schema order and in key order (`save_database_table()`, one transaction per `build: chunk_size` rows), the indexes, `ANALYZE`, the `build: pragmas_final` settings (checked by `validate_database_pragmas()`), and `VACUUM INTO` `<name>_new.sqlite`. Only then does the new file become the database, and the work file is removed.
- The load keeps the journal in memory (`journal_mode = MEMORY`) rather than off: with `journal_mode = OFF` SQLite cannot roll back, and a failed batch must leave no rows. Foreign keys are off during the load; the validation stage runs `foreign_key_check` and `integrity_check` once on the release file (G2 decision 9).
- Writes are plain `INSERT` statements through `DBI::dbAppendTable()`, so the keys, `UNIQUE`, `NOT NULL` and `CHECK` constraints of the schema reject a bad row and the error names the table and the batch. Never use `INSERT OR IGNORE`, `INSERT OR REPLACE` or a `try()` around a write; the tests of the writers scan their source for them.
- A build always starts from a new work file and never resumes; files left by a failed build are removed at the start of the next one. An existing database stops the build, unless `flag_replace_existing` is set, which is meant only for the disposable database of the `subset` profile. Code never deletes another database.

## Live database safety

The pipeline stages resolve the live database path with `resolve_database_path()` from the git-ignored `secrets.yaml` (`database_path`, and `database_v1_path` for the released v1 database). The legacy scripts and the website get `path_to_vegvault` from the compatibility `R/00_Config_file.R`, which resolves `database_v1_path` the same way; `secrets.yaml` replaces the former `.secrets/path.yaml`. Treat every resolved file as live user data. The `subset` profile uses a disposable database under the data root instead (see `.ai/analysis-structure.md`).

- Never display or commit `secrets.yaml`, `.secrets/` or a resolved private path.
- Never run database creation, a stage that builds or writes the database, `R/Analyses/00_run_main.R` or the legacy master workflow against the live path without explicit user authorization naming that target.
- For schema and import validation, create a new SQLite file in a temporary directory or use an explicitly identified disposable copy.
- Before any authorized overwrite, resolve the exact path, confirm it is not the only copy, report the expected tables/data affected, and preserve recovery options.
- Close DBI connections on success and failure (`run_with_database()` does both); avoid leaving locks on Windows.

## Schema changes

For any table, column, relationship, index, unit, or stored-value semantic change:

1. Update the executable SQL and DBML mirror.
2. Update affected `R/Functions/` writers and the imports (`R/Analyses/01_Producer_import/` and `R/Analyses/03_Database_assembly/`, and the legacy `R/02_Main_analyses/` scripts while they are in use).
3. Add or update focused validation in `R/Analyses/04_Validation/` or an appropriate disposable-schema check.
4. Update database version metadata and public website documentation.
5. Coordinate the independent `vaultkeepr` checkout, especially its `tests/testthat/helper_make_database.R` and `vignettes/helper_make_example_db.R` schema fixtures. Discover that checkout from the active workspace or user context; never assume a machine-specific location.
6. Test backward compatibility or document the minimum supported database version when compatibility cannot be retained.

Do not change only the package fixture or only the conceptual DBML file and claim the schema is updated.

## Import contracts

- Producer artifacts must be pinned to reviewed tags or immutable release identifiers and stable filenames.
- Validate required columns, classes, uniqueness, units, identifier domains, and row relationships before writing to SQLite.
- Preserve mandatory references and source-level provenance.
- Do not suppress SQL or import failures with broad `try()` calls without subsequently asserting that the intended schema/data exist.

## Proportional validation

Prefer a disposable empty-schema build and small representative import. Check expected tables, primary/foreign keys, indexes, row uniqueness, mandatory references, and the package's critical query chain. Run the full database assembly only when explicitly requested and justified by the change.

## Comparison with v1.0.0

The regional build of the `subset` profile is compared with the v1.0.0 subset of the same box that the database research extracted (`R/Analyses/90_Database_research/04_extract_v1_subset.R`), not by running the v1.0.0 writers again (decision on the assembly task, VegVault issue 90):

- `load_comparison_rows()` reads one kind of row (datasets, samples, sample taxa, age uncertainty, trait values, traits, abiotic variables and values, links, taxa, classification, references) by natural keys, read-only, from a file of either schema: the tables both schemas share have the same columns, and `AbioticDataReference` is a table in v1.0.0 and a view with the same columns in 2.0.0. Datasets and samples are identified by coordinates and ages, not by the names that 2.0.0 changes on purpose.
- `compute_comparison_summary()` counts, per kind of row and scope (dataset type and source, or variable), the rows of each side, of both and of one side only, and a checksum of each side; `compute_comparison_differences()` lists the rows that differ.
- `diagnose_comparison_summary()` marks every scope as equal, explained or unexplained against a list of expected differences, each with its direction (rows only in v1.0.0, only in 2.0.0, or both) and its reason. An unexplained difference fails the comparison.
- `R/Analyses/90_Database_research/23_compare_subset_with_v1.R` runs the comparison in the `subset` profile, after stages 01 to 03, with the kinds of rows and the expected differences of `comparison` in `research_settings.yml`. It reads both files read-only and writes `summary.csv` and the differing rows into a new folder under `Data/Temp/Database_research/Comparison`.
