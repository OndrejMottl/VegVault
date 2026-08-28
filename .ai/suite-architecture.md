# VegVault Suite Architecture and Data Contracts

This guide defines ownership and handoffs across the VegVault data-production repositories. The repositories form a release pipeline, not one shared Git repository.

## Repository ownership

| Repository | Owns | Downstream handoff |
| --- | --- | --- |
| `VegVault-FOSSILPOL` | Neotoma acquisition, chronology, harmonisation, filtering, pollen assembly, age uncertainty | Tagged files under `Outputs/Data/` plus metadata and references |
| `VegVault-Vegetation_data` | BIEN and sPlot acquisition, processing, review, and export | Tagged BIEN and sPlot `.qs` products under `Outputs/Data/` |
| `VegVault-abiotic_data` | CHELSA contemporary/palaeoclimate and WoSIS processing | Tagged batched `.qs` products under `Outputs/Data/` |
| `VegVault-Trait_data` | TRY and BIEN trait acquisition, processing, and export | Tagged TRY and partitioned BIEN trait `.qs` products under `Outputs/Data/` |
| `VegVault` | Pinned producer imports, SQLite schema and assembly, integration checks, releases, and project website | Versioned VegVault SQLite database and documentation |
| `vaultkeepr` | Independent user-facing R package for querying released VegVault databases | Package API, tests, vignettes, and pkgdown site |

The package has its own standalone `AGENTS.md` and `.ai/` guidance. Do not make `vaultkeepr` depend on this checkout for instructions or tests.

## Release and handoff contract

- Treat producer output filenames, column names, classes, units, identifiers, nesting, and partitioning as cross-repository interfaces.
- The integration repository must consume reviewed, tagged producer artifacts. Do not silently replace a tag or immutable artifact URL with a branch such as `main`.
- Before changing an output contract, identify every consumer in `VegVault/R/02_Main_analyses/`, relevant website documentation, and `vaultkeepr` if the resulting SQLite schema or semantics change.
- Coordinate changes in this order: producer implementation and validation, producer release/tag, pinned integration update, integration validation and database version update, documentation update, then downstream package compatibility work if needed.
- Preserve provenance: source version, acquisition date, processing version, tagged repository version, filename, and relevant licensing or citation requirements.

## Data and credential safety

- Never print, copy into documentation, commit, or disclose `.secrets/`, credentials, tokens, private paths, or private-source metadata.
- Respect TRY, sPlot, Neotoma/FOSSILPOL, BIEN, CHELSA, and WoSIS licence and reuse conditions. Do not infer that a locally present input may be redistributed.
- Do not add ignored raw inputs, temporary data, full rasters, model objects, or the live SQLite database to Git.
- Treat existing untracked data as user-owned. Do not inspect sensitive contents unless required for the task, and never delete or replace them as cleanup.
- `Data/Temp/` and other ignored caches must not contain the only copy of important decisions or irreplaceable data.

## Computational safety

The following operations are expensive or materially state-changing and require explicit user authorization: full upstream downloads, Bchron age-depth modelling, global raster processing, broad producer reruns, `R/01_Master.R`, `R/01_Data_processing/00_make_database.R`, and any operation that writes to the configured live database.

Before an authorized expensive run, report the entry point, inputs, output location, overwrite controls, expected scope, and whether the operation is restartable. Prefer a narrow script, small representative subset, manifest, or structural check when it can validate the change.

## Legacy code and focused changes

These repositories contain established script-cascade code. Apply current conventions to new and materially edited code, but do not turn a functional change into an unrelated repository-wide style rewrite. Preserve established public data contracts unless the task explicitly changes them.
