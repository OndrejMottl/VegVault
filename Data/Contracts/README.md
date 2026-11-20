# Producer artefact contracts

This folder holds one machine-readable contract per artefact that VegVault reads from a producer repository, the synthetic fixtures that satisfy (or deliberately break) each contract, and this description of the format. The contracts make the interface between the producers and VegVault explicit: file names, partitioning, column names and classes, missing values, units, nesting, keys and plausible values. VegVault's import validates every artefact against its contract before anything is written to SQLite, and producers validate their export against the same contract before tagging.

Status: proposed for gate G1 of the 2.0.0 release. The format, the plausible climate ranges and the consumption route below are agreed at G1; until then the contracts may change without a version bump.

## Contracts

| Contract | Producer | Files | Status |
| --- | --- | --- | --- |
| `splot_plots` | VegVault-Vegetation_data | `Outputs/Data/data_splot_<date>__<hash>__.qs` | active |
| `bien_plots` | VegVault-Vegetation_data | `Outputs/Data/data_bien_<date>__<hash>__.qs` | active |
| `fossilpol_assembly` | VegVault-FOSSILPOL | `Outputs/Data/data_assembly_light_<date>__<hash>__.qs` (or the full `data_assembly_<date>__<hash>__.rds`) | active |
| `fossilpol_age_uncertainty` | VegVault-FOSSILPOL | `Outputs/Data/data_age_uncertainty_<A, B, ...>_<date>__<hash>__.qs` | active |
| `try_traits` | VegVault-Trait_data | `Outputs/Data/data_trait_try_<date>__<hash>__.qs` | active; TRY kept (VegVault-Trait_data issue 13) |
| `bien_traits` | VegVault-Trait_data | `Outputs/Data/data_traits_bien_<0, 1, ...>_<date>__<hash>__.qs` | active |
| `chelsa_neoclimate` | VegVault-abiotic_data | `Outputs/Data/Neoclimate/CHELSA_bio_<NN>_<date>__<hash>__.qs`, one per variable | active |
| `chelsa_trace21k_palaeoclimate` | VegVault-abiotic_data | `Outputs/Data/Palaoclimate/bio<NN>_batch_<1, 2, ...>_<date>__<hash>__.qs` | active |
| `wosis_soil` | VegVault-abiotic_data | `Outputs/Data/WoSIS/wosis_data_<date>__<hash>__.qs` | active; the soil source is still to be settled in the source inventory (VegVault issue 82) |

FOSSILPOL has no references contract: VegVault takes references from the assembly's `doi` and `source_of_data` and does not read the producer's `Outputs/Meta_and_references/`.

## Contract format

A contract is a YAML file named `<contract_id>.yml`. `load_producer_contract()` reads it and rejects any field it does not know, so a typo fails loudly. Every entry that describes data carries an `evidence` field saying where the rule comes from: an import script and line, a producer script, or what the v1 artefact showed.

### Top-level fields

| Field | Required | Content |
| --- | --- | --- |
| `contract_id` | yes | Identifier; equals the file name without `.yml`. |
| `contract_version` | yes | Semantic version, for example `1.0.0` (see the change procedure). |
| `status` | yes | `active`, `conditional` or `retired`. |
| `status_note` | when not active | Why the contract is conditional or retired. |
| `title`, `description` | `title` | Human-readable name and summary. |
| `producer` | yes | `repository` and `directory` of the files in the producer. |
| `consumers` | yes | VegVault files that read the artefact. |
| `file` | yes | `name_templates` (one or more) and optional `evidence`. |
| `partitioning` | yes | `scheme`, and for partitioned artefacts `first` and `contiguous`. |
| `extra_columns` | no | `allow` (default) or `error` for columns the contract does not list. |
| `min_rows` | no | Least number of rows of every file (default 1, so an empty file is an error). |
| `columns` | yes | Column entries, see below. |
| `keys` | no | Sets of columns that must identify every row. |
| `rounded_keys` | no | Sets of columns that must identify every row after rounding, with `columns` and `digits`. |
| `dependencies` | no | Functional dependencies, for example one unit per trait. |
| `variables` | no | Per-variable table for artefacts with one file per variable. |
| `relations` | no | Links to other artefacts, checked by the import stage. |
| `notes` | no | Open points and context. |

### File names

`RUtilpol::save_latest_file()` names files `<name>_<date>__<hash>__.<extension>`. A template writes the name with placeholders: `{date}` (`YYYY-MM-DD`), `{hash}` (32 lower-case hexadecimal characters), `{partition}` and `{variable}`; every other character is literal. The hash is `rlang::hash()` of the saved R object, not a checksum of the file, so file integrity is checked separately by the pin manifest. Files ending in `.qs` hold `qs2` content (written by `qs2::qs_save()`, read with `qs2::qs_read()`); files ending in `.rds` are read with `readRDS()`.

Quote templates and tokens in YAML (`'data_splot_{date}__{hash}__.qs'`, `file_token: '01'`), and write any text that contains a colon followed by a space as a folded block (`evidence: >-`), because YAML would otherwise read it as a nested field.

### Partitioning

`scheme` is `none` (one file, or one file per variable), `integer` (`{partition}` is a number) or `letter` (`{partition}` is one capital letter). `first` is the first partition (for example `0`, `1` or `A`) and `contiguous` (default `true`) requires that no partition between `first` and the last one is missing. `count` (optional) fixes the number of partitions, which also catches a missing last partition. Two files for the same partition, for example two dates of the same output, are always an error: the caller must select exactly one; integer partitions compare as numbers, so `1` and `01` are the same partition. Partitions are counted per variable. Keys are checked on all partitions of a variable (or of the artefact) together.

### Column entries

Each entry has `name`, `class`, `nullable`, `description` and `evidence`, and may have `unit`, `checks` and `element`.

`class` is one of `character`, `numeric` (double or integer), `double`, `integer`, `logical`, `Date`, `factor`, `list`, `data.frame` or `matrix`. Factors and dates are not numeric. `nullable: false` forbids `NA` and `NaN`; in a nullable column `NaN` counts as missing and passes. A logical column that holds only missing values is accepted for any nullable atomic class, because a column without values is often stored that way. A column name that occurs twice in a data frame is an error, at any level.

`checks` may contain:

| Check | Meaning |
| --- | --- |
| `range` | `min` and/or `max`, inclusive unless `min_inclusive` or `max_inclusive` is `false`. |
| `finite` | No `Inf` or `-Inf`. |
| `whole_number` | No fractional values. |
| `allowed_values` | Every value is in the list. |
| `forbidden_values` | No value equals one in the list; numbers compare with a relative tolerance of 1e-9, so storage-type limits such as 6553.5 are found after scaling. |
| `pattern` | Text matches the regular expression. |
| `not_empty` | No empty strings. |

A column of class `list` (a list-column) needs an `element` entry describing every element:

- `class` (not `list`) and `nullable` (whether an element may be `NULL` or a single `NA`);
- for `data.frame` elements: `columns` (column entries, nested as deep as needed), `other_columns` (one rule for every column not listed, with `class`, `nullable`, `description`, optional `checks` and `forbidden_names`; used where column names are data, such as taxon counts), `extra_columns`, `keys` (unique within each element) and `min_rows`;
- for `matrix` elements: `value_class`, `checks`, `require_column_names` and `min_rows`; `nullable` also forbids missing values inside the matrices;
- for atomic elements: `checks`; `nullable` also forbids missing values inside the vectors.

### Keys, dependencies, variables and relations

`keys` is a list of column sets, written as `- [plot_observation_id]` or `- [long, lat, time_id]`; missing values count as equal. `rounded_keys` entries add `digits`: the numeric columns are rounded to that many decimals before the uniqueness check, for keys that the import turns into names with rounded coordinates (gridpoint names use 2 decimals). `dependencies` entries have `determinant` and `dependent` column lists; every value of the determinant must occur with one value of the dependent.

`variables` is used where an artefact has one file (or one set of batches) per variable: `value_column` names the column holding the values and `table` lists every variable with `variable`, `file_token` (the `{variable}` text in the file name), `unit`, `description`, `evidence` and optional `checks` that apply to `value_column` in that variable's files. Every variable must have files. The units and descriptions equal the strings the v1 import scripts hard-code, so the import can read them from here.

`relations` document links between columns of different artefacts or of different list-columns (for example every age-uncertainty dataset exists in the assembly, and the levels and counts of a dataset have the same samples). The contract validator does not evaluate them; the producer import stage checks them once both artefacts are loaded (`validate_fossilpol_relations()`, the target `check_fossilpol_relations`). A new relation needs a check there too.

## Validator

The functions live in `R/Functions/Contracts/`, one per file, each with a test in `R/Tests/testthat/`.

```r
validate_producer_artefact(
  contract = here::here("Data", "Contracts", "splot_plots.yml"),
  path_artefact = vec_paths_splot
)
```

`validate_producer_artefact()` takes the contract (a path or a loaded contract) and either the paths of every file of the artefact (`path_artefact`) or the objects in memory (`data_artefact`: a data frame, or a list of data frames named by their file names). For contracts with variables, `vec_variables` limits the check to some variables, so a large artefact can be validated one variable at a time. It checks file names and partitions, object classes and row counts, columns, nested elements, values, variable checks, keys, rounded keys and dependencies, and reports every violation at once; an empty artefact is an error. On failure it aborts with an error of class `producer_contract_error` whose message names the contract, file, column and rule, and whose field `findings` holds the full table. On success it returns the artefact unchanged, invisibly. It never writes to a database or a file. `diagnose_producer_artefact()` returns the same findings table without aborting.

Dependencies: `assertthat`, `cli`, `dplyr`, `purrr`, `qs2`, `rlang`, `stringr`, `tibble`, `vctrs` and `yaml` for the validator; `here` and `tidyr` for the fixture builders; `testthat` and `withr` for the tests.

Until the template layout adds `R/Tests/Run_tests.R`, run the tests from the repository root by sourcing every file in `R/Functions/` and calling `testthat::test_dir("R/Tests/testthat")`. The script `tests/test_contract_fixtures_integration.R` drives the v1 database writers with the fixtures in a temporary SQLite file.

## Fixtures

`fixtures/valid/<contract_id>/` holds a small synthetic artefact that satisfies its contract, and `fixtures/broken/<contract_id>/` one that breaks exactly one rule. All values are invented; none comes from a real dataset, because several sources restrict redistribution. The coordinates include points above 63.3 degrees north on both sides of the antimeridian for gridpoint-linkage tests, and the FOSSILPOL, climate and soil fixtures share datasets and grid cells.

| Contract | Broken variant |
| --- | --- |
| `splot_plots` | Two plots share `plot_observation_id`. |
| `bien_plots` | One `plot_data` element lacks `individual_count`. |
| `fossilpol_assembly` | One level has no `age`. |
| `fossilpol_age_uncertainty` | Parts A and C, no B. |
| `try_traits` | One record is not published. |
| `bien_traits` | Part 1 is present twice, from two runs. |
| `chelsa_neoclimate` | One bio12 value is the storage limit 6553.5. |
| `chelsa_trace21k_palaeoclimate` | One bio1 value is 99 degrees. |
| `wosis_soil` | Soil-class codes are stored as text. |

The fixtures are built by the `build_<contract_id>_fixture()` functions and written by `R/Contracts/build_contract_fixtures.R`, which checks every valid fixture passes and every broken one fails before writing. The output is deterministic: rebuilding gives byte-identical files, and the tests of each builder check that the shipped files equal what the builder produces. Existing fixtures are kept unless `flag_rewrite` is set to `TRUE` in the script, which deletes and rewrites them (a changed fixture gets a new hash in its file name).

```sh
Rscript R/Contracts/build_contract_fixtures.R
```

## How producers use the contracts

To be decided at gate G1. Two routes were considered.

1. **Pinned copy.** A producer keeps a copy of `Data/Contracts/` (contracts and fixtures) and `R/Functions/Contracts/` taken from one VegVault commit, records that commit, and validates its export with the copied functions. A producer test compares the copy with the sibling VegVault checkout at the recorded commit when the sibling is present and skips otherwise.
2. **Fetch at a pinned commit.** The producer reads the contracts and functions from the sibling checkout, or downloads them from GitHub, at a pinned commit, without keeping a copy.

| | Pinned copy | Fetch at a pinned commit |
| --- | --- | --- |
| Works offline and on machines without the sibling checkout | yes | only with the sibling checkout |
| A producer tag records exactly which contract it was validated against | yes, in its own history | only if the commit is pinned and the source stays reachable |
| Drift between producer and VegVault | caught by the drift test when the sibling is present | none while the pin is current |
| Follows the sibling-checkout convention of `AGENTS.md` | yes, for the drift test | yes |
| Risk | a stale copy if the drift test is skipped | running against whatever branch the sibling has checked out if the commit is not enforced |

Recommendation: the pinned copy. It keeps every producer tag reproducible on its own, works offline, and the drift test catches a stale copy whenever the sibling checkout is available. The copied functions need only the packages listed under Validator.

## Changing a contract

Contracts change only through the VegVault pipeline lane (lane L6, VegVault issue 92), in a pull request into the release branch.

1. Edit the contract and bump `contract_version`: major for a change that can reject an artefact that passed before (a new required column, a stricter class, range or key, a renamed or removed column); minor for a change that only accepts more (a new optional column, a relaxed check); patch for descriptions, evidence and notes.
2. Update the fixture builder if needed, rebuild the fixtures with `R/Contracts/build_contract_fixtures.R` (`flag_rewrite <- TRUE`), and run the tests and `tests/test_contract_fixtures_integration.R`.
3. Check every consumer: the VegVault import stage and, while they exist, the v1 import scripts listed under `consumers`; the database assembly that writes the imported rows; the website pages under `website/database_structure/`; and `vaultkeepr` if the change alters the SQLite schema or the meaning of stored values.
4. After the merge, the maintainer announces the new version in the release umbrella issue (VegVault issue 86), and each affected producer updates its copy and revalidates.
