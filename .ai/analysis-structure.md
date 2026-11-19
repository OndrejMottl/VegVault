# Analysis structure

VegVault is moving from a script cascade (`R/01_Master.R`) to the layout of the project template (`OndrejMottl/Project_template`, `.ai/analysis-structure.md`): numbered `{targets}` stages, configuration in `config.yml`, machine-local values in `secrets.yaml`, and one tested function per file. The layout is a contract. Change it deliberately, update this file in the same change, and check every caller.

## Layout

```text
config.yml                 project configuration, read via load_config_value()
secrets.yaml               git-ignored machine-local values (see secrets_example.yaml)
Data/
  Contracts/               producer artefact contracts and fixtures
  SQL/                     executable schema and its DBML mirror
  Temp/                    disposable scratch (git-ignored)
  Targets_data/            one {targets} store per pipeline (git-ignored)
Outputs/                   final outputs, organised by the analysis that made them
R/
  ___Init_project___.R     one-time package restore
  ___setup_project___.R    shared setup sourced by every stage, pipeline and test run
  package_dependencies.R   generated; do not edit
  Functions/<Area>/        one function per file, named after the function
  Analyses/
    00_run_main.R          runs every stage runner in order
    <NN>_<Stage>/
      00_run.R             runs the pipelines of the stage
      pipeline.R           declares one target graph
  Tests/
    Run_tests.R            full suite runner
    testthat/test-<function_name>.R
```

The legacy entry points stay in place until the stages replace them: `R/00_Config_file.R` (sourced by the website and the legacy scripts), `R/01_Master.R`, `R/01_Data_processing/`, `R/02_Main_analyses/`, `R/03_Visualisation/` and `R/04_Webiste/`.

## Stages and owners

During the 2.0.0 release two agent lanes work in this repository. Each edits only its own stages, function folders and `config.yml` sections; a change to another lane's files goes through that lane.

| Stage folder under `R/Analyses/` | Content | Owner |
| --- | --- | --- |
| `01_Producer_import` | Pinned producer artefacts, validated against their contracts | VegVault pipeline lane |
| `02_Gridpoints` | Gridpoints and their links to samples | Database-core lane |
| `03_Database_assembly` | Schema, table assembly and bulk writes, build manifest call | Database-core lane |
| `04_Validation` | Release checks of the built database | VegVault pipeline lane |
| `05_Export` | Flat-file export | VegVault pipeline lane |
| `06_Visualisation` | Manuscript figures | VegVault pipeline lane |

Other owned areas: `Data/Contracts/`, `R/Functions/Contracts/`, and the shared build helpers in `R/Functions/Database_access/`, `R/Functions/Build_manifest/` and `R/Functions/Build_profile/` (VegVault pipeline lane; the database-core lane calls them); `Data/SQL/`, `R/Functions/Database/` and `R/Functions/Gridpoints/` (database-core lane). `R/Functions/Workflow/` holds the template helpers, copied from the template at commit `95d176c`; change them only together with the template.

`config.yml` sections: `producers`, `subset`, `validation` and `export` belong to the VegVault pipeline lane, `link` and `build` to the database-core lane; `seed`, `data_storage_path`, `packages`, `graphical` and `database` are shared.

## Stages and pipelines

- A stage is a numbered folder under `R/Analyses/` for one operation. Numbers give the run order. Each stage has a `00_run.R` that sources the setup and calls `run_target_pipeline()` for each of its pipelines; `00_run_main.R` sources the stage runners in order.
- A `pipeline.R` only declares targets. It sources the setup, sets `targets::tar_option_set(seed = config_seed)`, and returns a list of targets. Sourcing it never builds targets.
- Each pipeline owns one store, resolved with `resolve_pipeline_store_path()` under `<data root>/Targets_data/`. Never share a store between pipelines.
- Target names are quoted strings. Above each target, a short plain comment says what it provides and why it is in the graph.
- When a target command is more than one function call, move the logic into a function in `R/Functions/`. The upstream-import target is the one exception.
- Never let a stage build, overwrite or hash the live database implicitly. Stages that read the database depend on the build manifest, not on the database file.

## Database access and the build manifest

- Open a database only through `run_with_database()`, which always disconnects, also after an error. Stages that only read use `flag_read_only = TRUE`.
- The last target of the database assembly calls `save_build_manifest()`. It writes `<database name>_build_manifest.yml` next to the database (`resolve_build_manifest_path()`) with the database file name, size and modification time, the profile and subset box, the version record, the producer pins, the git commit (`load_git_commit()`) and whether the checkout was clean (`is_git_clean()`), and the build time, and returns its path for a `format = "file"` target.
- Stages 04 to 06 depend on that manifest target and call `load_build_manifest(path_database = ...)`, which aborts when the database no longer matches its manifest. Before a release, pass `profile_expected = "release"`.
- A SHA-256 of the database is recorded only at release, outside `{targets}`.

## Cross-pipeline contracts

- A downstream pipeline imports only public targets of an upstream store. List them in the pipeline's "Upstream contract" section, together with the upstream runner.
- Import pattern: a `fingerprint_<stage>` target calls `compute_target_store_fingerprint()` with `cue = targets::tar_cue(mode = "always")`, and the import target references the fingerprint and calls `load_target_store_value()`.
- A missing upstream store or target is an error that names the runner to execute first (`validate_target_store_contract()`). It never silently triggers an expensive rebuild.
- Renaming or removing a public target is a contract change: search all downstream pipelines first.

## Configuration and secrets

- Analysis values live in `config.yml` and are read only through `load_config_value()`. Do not call `config::get()` directly.
- Profiles other than `default` are selected with `R_CONFIG_ACTIVE` and inherit from `default`. Each profile sets `profile` to its own name, which the build manifest records:
  - `default`: the full build during development.
  - `subset`: the regional rehearsal build. Its `subset` section enables a bounding box (`alaska_yukon`) and names a disposable database relative to the data root. Cut validated artefact tables to the box with `filter_by_bounding_box()`.
  - `release`: the published build.
- `validate_build_profile()` enforces that only the `subset` profile enables the box, so the `release` profile refuses to run with it, and that a `release` build runs from a clean checkout (no uncommitted or untracked files). Call it before an expensive build step.
- The data root comes from `resolve_data_storage_path()`: the `Data` entry of `secrets.yaml` if present, otherwise `data_storage_path` in `config.yml` (the repository's `Data/`).
- The live and v1 database paths are never written in code or `config.yml`. `resolve_database_path()` reads them from `secrets.yaml`: `database_path` for the database being built and `database_v1_path` for the released v1.0.0 database, opened read-only. Create `secrets.yaml` from `secrets_example.yaml`; never print, copy or commit its values.
- The one exception is the disposable database of the `subset` profile: there, `resolve_database_path()` returns `subset: database_file` under the data root and reads no database path from `secrets.yaml`, so a rehearsal cannot open the live database. `validate_subset_database_file()` keeps that file under the data root (a relative path without `..`).
- The setup calls `validate_config_profile()`, which aborts when `R_CONFIG_ACTIVE` names a profile that `config.yml` does not define; `{config}` would otherwise fall back to `default` without a warning.

## Setup and packages

- Every stage runner, pipeline and test run starts with `library(here)` and `source(here::here("R/___setup_project___.R"))`.
- The setup aborts if `R_CONFIG_ACTIVE` names an unknown profile or the data root does not exist, loads every file in `R/Functions/`, attaches `packages: attach` from `config.yml`, regenerates `R/package_dependencies.R`, sets the seed and the ggplot theme, and resolves `path_data_storage`.
- The lockfile is still `renv/library_list.lock` (see `.ai/r-environment.md`); the switch to the template's `renv.lock` follows when the legacy entry points stop restoring from it.

## Tests

- Every function in `R/Functions/` has `R/Tests/testthat/test-<function_name>.R`. Shared fixtures go in `helper-*.R` files.
- `Rscript R/Tests/Run_tests.R` validates the function files (`validate_function_names()`) and runs the suite in a clean subprocess (`run_project_tests()`). Until the legacy functions are renamed to approved verbs, the name check covers only `Workflow/`, `Contracts/`, `Database/`, `Gridpoints/`, `Database_access/`, `Build_manifest/` and `Build_profile/`.
- Focused run: source the setup, then `run_test_file(test_file = ...)`.
- Script-level integration checks that are not function tests, such as `tests/test_trait_v2_integration.R`, run directly with `Rscript` and use a temporary database.
