# VegVault Database and Schema Guidance

Apply this guide to SQLite schema files, database assembly code, import scripts, validation scripts, and downstream schema compatibility work.

## Authoritative schema

- `Data/SQL/make_tables.sql` is the executable schema used by `R/01_Data_processing/00_make_database.R`.
- `Data/SQL/database_structure.dbml` is the maintained conceptual diagram and must remain semantically aligned with the executable schema.
- Website pages under `website/database_structure/` document the public schema and must be updated when released tables, columns, relationships, units, or meanings change.
- `R/00_Config_file.R` owns database version metadata. A released schema or semantic contract change requires an intentional version/changelog update.

## Live database safety

`R/00_Config_file.R` resolves `path_to_vegvault` from `.secrets/path.yaml`. Treat that resolved file as live user data.

- Never display or commit the secret file or resolved private path.
- Never run database creation or the full master workflow against the live path without explicit user authorization naming that target.
- For schema and import validation, create a new SQLite file in a temporary directory or use an explicitly identified disposable copy.
- Before any authorized overwrite, resolve the exact path, confirm it is not the only copy, report the expected tables/data affected, and preserve recovery options.
- Close DBI connections on success and failure; avoid leaving locks on Windows.

## Schema changes

For any table, column, relationship, index, unit, or stored-value semantic change:

1. Update the executable SQL and DBML mirror.
2. Update affected `R/Functions/` writers and `R/02_Main_analyses/` imports.
3. Add or update focused validation in `R/02_Main_analyses/11_Check_database.R` or an appropriate disposable-schema check.
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
