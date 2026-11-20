# VegVault Database and Schema Guidance

Apply this guide to SQLite schema files, database assembly code, import scripts, validation scripts, and downstream schema compatibility work.

## Authoritative schema

- `Data/SQL/make_tables.sql` is the executable schema. The database assembly stage (`R/Analyses/03_Database_assembly/`) builds the database from it, and so does the legacy `R/01_Data_processing/00_make_database.R` until that stage replaces it. Tests build it into a temporary file with `build_database_fixture()`.
- `Data/SQL/database_structure.dbml` is the maintained conceptual diagram and must remain semantically aligned with the executable schema.
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
