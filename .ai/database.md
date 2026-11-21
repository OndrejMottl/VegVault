# VegVault Database and Schema Guidance

Apply this guide to SQLite schema files, database assembly code, import scripts, validation scripts, and downstream schema compatibility work.

## Authoritative schema

- `Data/SQL/make_tables.sql` is the executable schema. Create it only with `build_database_schema()` (`R/Functions/Database/`): it runs the file statement by statement in one transaction, stops at the first failed statement, and then checks the database with `validate_database_schema()`, which compares every table, view and index with the file. The database assembly stage (`R/Analyses/03_Database_assembly/`) builds the database this way, and so does the legacy `R/01_Data_processing/00_make_database.R` until that stage replaces it. Tests build it into a temporary file with `build_database_schema()` or `build_database_fixture()`.
- The file has two sections: the tables and the view, with every key and constraint declared in the tables, and then all secondary indexes. A bulk load calls `build_database_schema(sel_objects = "tables")`, loads the rows, and then calls it with `sel_objects = "indexes"`. Keep every `CREATE INDEX` in the second section and use semicolons only to end statements (two test scripts in `tests/` still split the file at every semicolon).
- Links between samples and gridpoint samples are stored once per position (`Positions`, `SamplePosition`, `PositionLink`). The gridpoint stage computes them as targets (see `.ai/analysis-structure.md`); the assembly stage writes them. `AbioticDataReference` is a view that returns them once per sample with the v1.0.0 columns; nothing can be written to it, and `DBI::dbListTables()` lists it with the tables.
- `Data/SQL/database_structure.dbml` is the maintained conceptual diagram and must remain semantically aligned with the executable schema. The test of `build_database_schema()` compares the tables, columns, types, primary keys, `NOT NULL` and references of both files (read with `load_dbml_structure()`), so change them together.
- Website pages under `website/database_structure/` document the public schema and must be updated when released tables, columns, relationships, units, or meanings change.
- The database version record is `database: versions` in `config.yml`; its last entry is the version being built. The compatibility `R/00_Config_file.R` reads it from there for the legacy scripts and the website. A released schema or semantic contract change requires an intentional version/changelog update.

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
3. Add or update focused validation in `R/Analyses/04_Validation/` (the legacy checks are in `R/02_Main_analyses/11_Check_database.R`) or an appropriate disposable-schema check.
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
