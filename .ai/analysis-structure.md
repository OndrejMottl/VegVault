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
| `05_Export` | Flat-file export: every table as CSV, column names and types per table, and a Word list of all columns | VegVault pipeline lane |
| `06_Visualisation` | Manuscript figures: the ten figures of the v1 manuscript, drawn from the built database | VegVault pipeline lane |

Other owned areas: `Data/Contracts/`, `R/Functions/Contracts/`, `R/Functions/Export/`, `R/Functions/Figures/`, `R/Functions/Fixtures/`, and the shared build helpers in `R/Functions/Database_access/`, `R/Functions/Build_manifest/` and `R/Functions/Build_profile/` (VegVault pipeline lane; the database-core lane calls them); `Data/SQL/`, `R/Functions/Database/` and `R/Functions/Gridpoints/` (database-core lane). `R/Functions/Workflow/` holds the template helpers, copied from the template at commit `95d176c` (change those only together with the template; `validate_target_store_contract()` has a check of the latest run that the template does not have yet), and two VegVault path resolvers of the VegVault pipeline lane: `resolve_database_path()` and `resolve_output_dir()`.

`config.yml` sections: `producers`, `subset`, `validation`, `export` and `figures` belong to the VegVault pipeline lane, `link` and `build` to the database-core lane; `seed`, `data_storage_path`, `packages`, `graphical` and `database` are shared.

## Stages and pipelines

- A stage is a numbered folder under `R/Analyses/` for one operation. Numbers give the run order. Each stage has a `00_run.R` that sources the setup and calls `run_target_pipeline()` for each of its pipelines; `00_run_main.R` sources the stage runners in order.
- A `pipeline.R` only declares targets. It sources the setup, sets `targets::tar_option_set(seed = config_seed)`, and returns a list of targets. Sourcing it never builds targets.
- Each pipeline owns one store, resolved with `resolve_pipeline_store_path()` under `<data root>/Targets_data/`. Never share a store between pipelines.
- Target names are quoted strings. Above each target, a short plain comment says what it provides and why it is in the graph.
- A target name must not repeat the name of an object the setup creates (such as `config_seed`, `config_profile` or `path_data_storage`); `{targets}` ignores the global object and the graph is no longer what it looks like.
- Branching patterns are written as bare `map()`, `cross()` and so on: `{targets}` accepts only the names from `tar_pattern()` there, not `targets::map()`.
- Functions in `R/Functions/` never call themselves or each other in a loop by name. `{targets}` reads such calls as a cycle and refuses every pipeline. A recursive function captures itself with `base::sys.function()` and calls that handle; two functions that recurse into each other pass the caller's handle as an argument (see `diagnose_producer_column_specs()`).
- Settings that may change between runs (paths from `secrets.yaml`, values from `config.yml`, external tools) are read in targets with `cue = targets::tar_cue(mode = "always")`. They are cheap, and downstream targets rerun only when their value changes.
- Read the smallest `config.yml` section a target needs (for example `c("figures", "taxon_example")`, not `"figures"`), so that a changed setting reruns only the targets that use it.
- When a target command is more than one function call, move the logic into a function in `R/Functions/`. The upstream-import target is the one exception.
- Never let a stage build, overwrite or hash the live database implicitly. Stages that read the database depend on the build manifest, not on the database file.

## External tools

- `05_Export` needs the `sqlite3` command-line tool on the `PATH` (on Windows: `winget install --exact --id SQLite.SQLite`, then open a new terminal) and Quarto, whose bundled pandoc renders the Word list of columns.
- `06_Visualisation` needs the `maps` package (country outlines; listed under `packages: tools` because no code calls it by name), `vaultkeepr` for the five vaultkeepr figures, and internet access the first time it loads the GADM border of the gridpoint figure.

## Producer pins

- `Data/Producers/producer_manifest.yml` pins every producer artefact VegVault reads: one entry per contract of `Data/Contracts/`, with the contract version, a `release` part (tag and every file's name, size and SHA-256) and a `dev` part (explicit local file names). The contract gives the producer repository, the directory and the file-name templates. `load_producer_manifest()` checks the manifest against its format and the contracts, needs an entry for every contract that is not `retired`, and reports every problem at once.
- `producers: mode` of `config.yml` selects how artefacts are resolved (`resolve_producer_artefact()`):
  - `dev` (default and `subset` profiles) reads the files listed under `dev` from the sibling producer checkouts under `producers: dev_root` (`<dev_root>/<repository name>/<directory>/<file name>`), never downloads, and records the size and checksum it found;
  - `release` (`release` profile) accepts only `v<major>.<minor>.<patch>` tags, fetches each file from the raw GitHub URL at the tag (`producers: release_url_template`) into the cache `<data root>/<producers: cache_dir>/<sha256>/<file name>`, reuses a cached file with the pinned checksum, and aborts on a placeholder, a failed download, or a checksum or size mismatch.
- `load_producer_artefact()` reads the resolved files (`qs2` for `.qs`, `readRDS()` for `.rds`) into the named list that `validate_producer_artefact()` takes. Checksums are verified when an artefact is resolved, not when it is read.
- `release.tag: null` with no files is a placeholder until the producer tags; an empty `dev.files` is a placeholder until a producer output exists. Both make their mode fail for that artefact. Fill an entry only together with the producer output or release it pins; the SHA-256 is computed by VegVault (`compute_file_sha256()`), never taken from the hash in the file name.
- The stage `01_Producer_import` declares its settings targets in its `pipeline.R` and every other target with `build_producer_import_targets()`. Per artefact it has `file_contract_<id>`, `data_files_<id>` (resolved on every run, so every checksum is computed again and a changed file is never used under an old pin) and the validated data `data_<id>` (`format = "qs"`, a named list of tables, one per file). The two CHELSA artefacts have, per variable, a file selection `data_files_<id>_<variable>` (`filter_producer_files()`) and a data target `data_<id>_<variable>`, so the palaeoclimate data is never in memory at once and a changed file rebuilds only its variable. A failed contract check stops the stage with a message that names the artefact, the file, the column and the rule.
- `profile_build` and `mode_producers` stop the stage before anything is resolved when the profile does not fit: the release profile refuses the subset and uncommitted code (`validate_build_profile()`) and needs `producers: mode: release` (`resolve_producer_mode()`).
- In the `subset` profile every data target is cut to the box (`list_subset_box`, only the bounds and margins of the `subset` section) by `filter_producer_artefact()`, with one rule per artefact in `producers: subset_filter`: by coordinates, widened by the subset margins for the climate and soil grids, and the FOSSILPOL age uncertainty by the datasets the cut assembly kept (`vec_keys_fossilpol_assembly_dataset_id`, from `prepare_producer_keys()`). Rows without coordinates are dropped, trait records included. A changed rule rebuilds only that artefact's data.
- `check_fossilpol_relations` checks the `relations` of the FOSSILPOL contracts (`validate_fossilpol_relations()`). `data_chelsa_trace21k_coordinates`, `vec_chelsa_trace21k_ages` and `data_chelsa_neoclimate_coordinates` give the gridpoint stage its grid without the climate values. `list_producer_pins` is what the database assembly passes to `save_build_manifest()`.
- The public targets are listed in the pipeline's "Public targets" section. Their names are a proposal until the database-core lane agrees them; only then do stages 02 and 03 import them.
- After a failed run `{targets}` keeps the last good value of an errored target. `validate_target_store_contract()` therefore refuses to import from a stage-01 store whose latest run failed, was interrupted or did not reach the imported targets. One store serves every profile, and a store whose latest run finished in another profile passes that check: stage 03 compares the public target `profile_build` with its own profile.

## Export stage

- Every export file is a `format = "file"` target, so `{targets}` writes it again after a new build (a new manifest), after a code change, or when the file is missing or was changed, and otherwise leaves it alone. `export: rewrite: true` in `config.yml` forces every file to be written again (`build_export_cue()`). Export functions always write when they run; they do not skip existing files themselves.
- Files of tables that a new build no longer has are not deleted; remove them by hand.

## Figure stage

- Each figure is a chain of targets: one or more `data_*` targets that read the database, a `fig_*` target with the plot object (`plot_*()` functions return plots and never save them), and a `file_fig_*` target with `format = "file"` that `save_manuscript_figure()` writes into `figures: output_dir`. The default folder is the tracked `Outputs/Figures/mns/` with the v1 file names; the `subset` profile writes to `Data/Temp/Subset/Figures/`.
- Every data target takes the build manifest, so a new build redraws all figures. Figures that only count or list records read the database through `run_with_database(flag_read_only = TRUE)`. The five vaultkeepr figures extract through `vaultkeepr`, which opens the database read-write; their loaders only read and always close the connection.
- `figures: files` gives each figure its file name, a width name of `graphical: manuscript: image_width` and a height. `build_figure_style()` turns `graphical: manuscript` and `colors.json` into the theme, sizes, colours and palettes that every plot function takes; the theme keeps the v1 manuscript look (`theme_minimal()` based) instead of the project default `theme_classic()`.
- In the `subset` profile every example region is replaced by the subset box (`resolve_figure_region()`), so a rehearsal database still yields data.
- The sample-age figure shows the dataset named in `figures: sample_age: dataset_name`, because dataset IDs change with every build; until a name is set, its data target stops with a message. Its three targets have `error = "continue"`, so the other figures are still drawn. A target downstream of a target with `error = "continue"` needs the same setting: on the default `"stop"` it ends the whole run when it cannot load the errored input.
- Each setting is read by its own always-run target, one value per target (`sel_*`, `list_region_*`, `list_file_*`), so that a changed label or size never extracts data from the database again.
- Draw country outlines with `build_world_borders_layer()`; `ggplot2::annotation_borders()` fails in facetted plots. Add `coord_sf()` after `geom_sf()`, which brings its own default `coord_sf()` that would replace an earlier one and drop the extent.

## Database access and the build manifest

- Open a database only through `run_with_database()`, which always disconnects, also after an error. Stages that only read use `flag_read_only = TRUE`.
- The last target of the database assembly calls `save_build_manifest()`. It writes `<database name>_build_manifest.yml` next to the database (`resolve_build_manifest_path()`) with the database file name, size and modification time, the profile and subset box, the version record, the producer pins, the git commit (`load_git_commit()`) and whether the checkout was clean (`is_git_clean()`), and the build time, and returns its path for a `format = "file"` target.
- Stages 04 to 06 depend on that manifest target and call `load_build_manifest(path_database = ...)`, which aborts when the database no longer matches its manifest. Before a release, pass `profile_expected = "release"`.
- A SHA-256 of the database is recorded only at release, outside `{targets}`.

## Cross-pipeline contracts

- A downstream pipeline imports only public targets of an upstream store. List them in the pipeline's "Upstream contract" section, together with the upstream runner.
- Import pattern: a `fingerprint_<stage>` target calls `compute_target_store_fingerprint()` with `cue = targets::tar_cue(mode = "always")`, and the import target references the fingerprint and calls `load_target_store_value()`.
- A missing upstream store or target is an error that names the runner to execute first (`validate_target_store_contract()`). It never silently triggers an expensive rebuild.
- So is an upstream store whose latest run did not finish (a target errored, was canceled or was left running) or did not build or check every imported target, for example a run of selected targets only. `{targets}` keeps the last good value of a failed target, so such a store may hold stale values. The check reads `targets::tar_progress()`, which covers only the latest run.
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
- The lockfile is the template's `renv.lock`, restored once per checkout with `Rscript R/___Init_project___.R` (see `.ai/r-environment.md`).
- `R/00_Config_file.R` is a compatibility file for the legacy scripts and the website: it sources the setup and keeps the objects they use, `path_to_vegvault` (the v1 database, `database_v1_path` of `secrets.yaml`), `data_version_control` and `db_version` (from `database: versions` of `config.yml`). Remove it when they move to the new setup, after the 2.0.0 release.

## Tests

- Every function in `R/Functions/` has `R/Tests/testthat/test-<function_name>.R`. Shared fixtures go in `helper-*.R` files.
- Functions that read the database are tested on `build_database_fixture()`, a small SQLite file with the full schema and fixed rows (documented in its roxygen) that also serves the `vaultkeepr` queries of the figures. Never test against the live or v1 database.
- `setup-graphics_device.R` sends the drawing of figure tests to a temporary PDF, so no `Rplots.pdf` is left in the test folder.
- Producer pins are tested on `build_producer_manifest_fixture()`, which copies the valid contract fixtures into local stand-ins for the releases and the sibling checkouts and pins them with `file://` URLs. No test downloads from the network. The test of `build_producer_import_targets()` runs the stage's targets with `tar_make(callr_function = NULL)` on a fixture manifest of every contract, in a temporary store; in that mode the script runs in the test's environment, so no local object may be named like a target.
- `Rscript R/Tests/Run_tests.R` validates the function files (`validate_function_names()`) and runs the suite in a clean subprocess (`run_project_tests()`). Until the legacy writers are renamed to approved verbs, the name check covers only `Workflow/`, `Contracts/`, `Database/`, `Gridpoints/`, `Database_access/`, `Build_manifest/`, `Build_profile/`, `Export/`, `Figures/`, `Fixtures/`, `Producers/` and `Visualisation/`. The database-core lane renames the remaining `add_*()` writers and the legacy gridpoint functions (`bin_coord_data()`, `get_gridpoints_link()`, `get_valid_gridpoints_ids()`) when it rewrites them.
- Focused run: source the setup, then `run_test_file(test_file = ...)`.
- Script-level integration checks that are not function tests, such as `tests/test_trait_v2_integration.R`, run directly with `Rscript` and use a temporary database.
