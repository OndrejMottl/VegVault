# VegVault R Coding Guidance

Canonical R guidance for scripts, reusable functions, data processing, database assembly, and visualisation in the VegVault integration and producer repositories. Repository-local contracts take precedence for domain-specific inputs, expensive operations, licences, and output contracts.

## Scope and legacy code

Apply these conventions to new and materially edited R code. Preserve readable established idioms in untouched legacy sections; do not turn a focused change into a repository-wide restyle. When editing an old block substantially, bring that block toward this guide without changing behavior accidentally.

The main areas of the VegVault repository are (`.ai/analysis-structure.md` describes the stage layout):

- `R/___setup_project___.R`, `config.yml` and the git-ignored `secrets.yaml`: shared setup, settings, and machine-local paths
- `R/Analyses/`: the `{targets}` stages, each run through its `00_run.R` (all of them through `00_run_main.R`); never run a stage that builds or writes the database without explicit authorization
- `R/Functions/`: reusable project functions, with tests in `R/Tests/testthat/`
- `R/00_Config_file.R`, `R/02_Main_analyses/12_Export_db_flat.R` and `R/03_Visualisation/`: the remaining legacy entry points, kept until the stages replace them; the website still sources `R/00_Config_file.R`. The v1.0.0 database build (`R/01_Master.R`, `R/01_Data_processing/`, import scripts `01` to `10`) is deleted
- `R/04_Webiste/`: website-support code, retaining the repository's historical directory spelling

## Project setup and clean execution

Use `R/___Init_project___.R` only for one-time machine setup; it may install packages or restore `renv`. Executable scripts load the repository configuration from a clean R session. In VegVault, stage runners, pipelines and tests source the project setup:

```r
library(here)

source(
  here::here("R/___setup_project___.R")
)
```

The legacy VegVault scripts, the website and the producer repositories source their `R/00_Config_file.R` the same way.

Do not rely on objects, options, packages, connections, or environment variables left by an interactive session. A reusable function must not source setup files or attach packages.

The R version, `renv` lockfile, package changes, artefact formats, and test runs are covered in `.ai/r-environment.md`.

## Script structure

- Give each script one clear responsibility.
- Preserve the existing VegVault banner in top-level scripts.
- Separate setup, inputs, transformations, outputs, and checks with numbered IDE-navigation headers.
- Keep reusable logic in `R/Functions/`; orchestration scripts should call functions rather than define them inline.
- Keep ordered filenames when the number represents a real workflow dependency.

Section pattern:

```r
#----------------------------------------------------------#
# 2. Validate imported records -----
#----------------------------------------------------------#
```

Comments explain scientific meaning, contract decisions, units, provenance, or non-obvious reasons. Do not narrate syntax that is already clear from the code.

## Naming

Use lower `snake_case` and descriptive full words. Function names are verbs; data objects are nouns.

Prefer type prefixes for important objects:

- `data_*`: data frames, tibbles, or lazy tables
- `table_*`: summaries intended as tables
- `list_*`: lists
- `vec_*`: vectors
- `mat_*`: matrices
- `mod_*`: fitted models
- `plot_*`: plot objects
- `path_*`: paths
- `flag_*`: logical controls
- `res_*`: function results

Do not encode issue numbers, pull-request numbers, or temporary plan stages in R identifiers, target names, filenames, comments, or configuration values. Name code after its scientific or computational role.

Treat assigned R objects as immutable within their lexical scope. Once an
object name has received a value, do not assign another value to that name and
do not change its columns, elements, or attributes in place. Every filtered,
validated, enriched, selected, or otherwise transformed state gets a new,
descriptive object name. Do not overwrite function arguments.

```r
data_samples_raw <-
  readr::read_csv(path_samples)

data_samples_valid <-
  validate_samples(data_samples_raw)

data_samples_selected <-
  dplyr::filter(data_samples_valid, .data$quality_flag == "accepted")
```

Memory or performance concerns do not silently override this rule. If measured
constraints make reassignment necessary, obtain explicit user approval for that
exception and document its scope and evidence.

## Formatting

- Use `<-` for assignment, two-space indentation, and `TRUE`/`FALSE`.
- Keep R and roxygen lines near 80 characters; do not impose that limit on Markdown or Quarto prose.
- Use explicit argument names when they improve clarity.
- Put one argument per line in multi-argument calls.
- Place the right-hand side on the next line after `<-` for calls, indexing, calculations, collections, conditionals, and pipelines.
- Short atomic literals and direct aliases may stay on the assignment line.

```r
path_output <- here::here("Outputs", "Tables")
flag_rewrite <- FALSE

data_summary <-
  summarise_imported_records(
    data = data_records,
    group_columns = vec_group_columns
  )
```

Separate top-level executable statements within a block with one blank line. Do not add blank lines inside a syntactically connected expression merely to separate arguments or pipeline stages.

Write control-flow conditions across lines:

```r
if (
  base::nrow(data_records) == 0L
) {
  cli::cli_abort("No records are available for import.")
}
```

Keep `} else {` together. Avoid dense one-line control flow and compound side effects.

## Namespaces and dependencies

- Use `pkg::function()` for non-base calls.
- Keep package attachment in project setup, not reusable functions.
- A new dependency requires a concrete benefit and explicit user approval before installation, lockfile changes, or use in committed project code.
- Use `base::file.path()` only for paths rooted in an already resolved external directory; use `here::here()` for repository paths.
- Never hardcode machine-specific absolute paths.

## Pipes and tidy data

Prefer `|>` in new self-contained code. Preserve `%>%` where an established block, magrittr placeholder, or lazy-query idiom makes conversion risky; do not mix pipe styles within one coherent pipeline.

Prefer modern, explicit operations:

- `dplyr::mutate()`, `filter()`, `select()`, `summarise()`
- `dplyr::join_by()` for new joins when supported by the locked environment
- `purrr::map()`, `imap()`, `map2()`, or `pmap()` followed by explicit `bind_rows()`/`bind_cols()`
- `stringr::str_glue()` for interpolation and `stringr::str_c()` for concatenation
- `readr::read_csv()` and `readr::write_csv()` for new CSV workflows when consistent with the repository environment

Avoid in new code:

- `eval(parse(...))`, `get()` in data masks, or hidden global lookup
- superseded `purrr::*_dfr()` and `*_dfc()` shortcuts
- growing vectors or data frames iteratively in loops
- silent many-to-many joins
- implicit partial matching

After grouped summaries, use `.groups = "drop"` or `dplyr::ungroup()` unless grouped output is the intentional contract.

## Data masking

Forward bare column arguments with `{{ }}`:

```r
summarise_values <- function(data_input, group_column) {
  res <-
    data_input |>
    dplyr::group_by({{ group_column }}) |>
    dplyr::summarise(
      n_records = dplyr::n(),
      .groups = "drop"
    )

  return(res)
}
```

Use `.data[[column_name]]` when a column name is stored as a character value. In legacy magrittr functions, preserve the established `.data <- rlang::.data` binding where it is needed for package checks.

## Paths, inputs, and outputs

- Use `here::here()` for repository files and the configured external-storage path for external data.
- Do not inspect, print, or expose `.secrets/` values.
- Treat date/hash-bearing producer filenames as release contracts.
- Preserve safe defaults such as `rewrite_files = FALSE`, `overwrite = FALSE`, and equivalent `flag_*` controls.
- Create output directories explicitly and recursively when the function or script owns that side effect.
- Never add ignored raw data, raster caches, model objects, or SQLite databases to Git.

Before reading or writing an expensive artifact, validate its path, expected schema, version/tag, and overwrite behavior.

## Reusable functions

- Also read and follow `.ai/r-functions.md` whenever creating or editing a
  function or its tests. That guide defines the binding one-function-per-file,
  roxygen2, matching-test-file, helper-exception, and strict-TDD contracts.
- Validate caller inputs early and fail with actionable messages.
- End with an explicit `return(res)` or a descriptively named result.
- Do not mutate global state, open an undeclared live connection, or write files unless that side effect is part of the documented contract.
- Move multi-step orchestration logic out of import/database scripts when it can be tested independently.

## Database code

Also follow `.ai/database.md`.

- Use explicit DBI connection ownership and close locally owned connections on success and failure.
- Parameterize values rather than constructing SQL with untrusted text.
- Validate table/column existence, keys, units, and row relationships before persistent writes.
- Do not suppress failures with broad `try()` calls and then continue as if a write succeeded.
- Test schema and import logic against a temporary SQLite database or disposable copy, never the configured live path.

## Performance

Profile before optimizing. Prefer reducing downloads, repeated parsing, raster reads, joins, database round trips, and full-object copies before introducing parallelism.

- Filter/select early and avoid collecting more data than needed.
- Preallocate loop results or use `purrr::map()`; do not repeatedly grow objects.
- Cache expensive deterministic intermediates only when provenance and invalidation are explicit.
- Use parallel processing only for independent CPU-heavy work whose cost exceeds startup and serialization overhead.
- Preserve restartability and safe overwrite controls in long workflows.

## Visualisation

- Reuse project palettes, sizes, themes, and semantic colour meanings.
- Build plots in the order: `ggplot()`, facets, scales, labels, themes, then geoms from bottom to top visual layer.
- Separate reusable plot construction from saving.
- Save only to the established output location with stable descriptive filenames.
- Verify final dimensions, labels, clipping, legends, and colours visually when a figure changes.

## Reproducibility and validation

- Set seeds explicitly whenever randomness affects results.
- Preserve source versions, producer tags, acquisition dates, hashes, units, and citations.
- Do not use environment variables as hidden switches for normal analysis logic; prefer explicit arguments or configuration values.
- Start validation with parsing/sourcing the smallest affected component in a clean session.
- Broaden to focused functions, representative subsets, disposable schema checks, and downstream contracts as risk increases.
- Do not run a full producer pipeline, a stage that builds the database, or database assembly solely to validate formatting or documentation.
