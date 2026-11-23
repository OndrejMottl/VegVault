# VegVault 2.0.0 database design (D1)

Status: draft for review. Questions 1 to 7 are answered, with one recommendation each and the decisions for gate G2 at the end. Gate G2 has not taken place. The National Repository constraints (question 6) are still to be reported by VegVault issue 85. The summary tables behind the numbers are in `Database_design_2.0.0_tables/` next to this note.

This note answers the seven questions of task D1 (VegVault issue 87) with measured numbers, and ends with one recommendation per question and the decisions for gate G2. Every number names its source: the script in `R/Analyses/90_Database_research/`, the data it ran on (v1.0.0 read-only, or the regional subset), and whether it is measured, estimated from a random draw, or extrapolated.

## How v1.0.0 was read

v1.0.0 was opened only read-only: by RSQLite with `SQLITE_RO`, and by the official `sqlite3` command-line tool 3.54.1 with `-readonly` and `PRAGMA query_only = 1` (needed for the `dbstat` table, which neither RSQLite 3.53.3 nor Python's SQLite is compiled with). Before and after every session the scripts compare the file size, the modification time and the 100-byte header (including the file change counter), and check that no `-journal`, `-wal` or `-shm` file appears next to the database; the file is opened only if its header shows rollback-journal mode. All sessions reported the file unchanged. Two sessions ended before their own check: the first attempt of `06_scan_v1_full.R`, which stopped on a script error after the `dbstat` pass, and the first call of `12_profile_vaultkeepr_queries.R`, which stopped in its post-processing after all workloads had finished. In both cases the comparison was run afterwards against the baseline of `01_inspect_v1_metadata.R` (size, modification time, file change counter 6991, page count) and found the file unchanged. The path is resolved from the git-ignored secrets file and is never printed, logged or committed; error messages of the command-line tool are redacted before they are shown.

The regional subset is a 2.5 GB copy of v1.0.0 content for the Alaska–Yukon box (longitude −170 to −125, latitude 54 to 72), made by `04_extract_v1_subset.R`: every non-gridpoint dataset in the box with all its rows and original ids, the gridpoints in the box plus a margin (0.5° latitude, 1.5° longitude), and every gridpoint those datasets link to. It is the only candidate box that holds every source type and content north of 63.3°, where the v1 linkage is known to lose links (`03_count_v1_candidate_boxes.R`). It holds 154,069 non-gridpoint samples, 82,282 gridpoint samples and 48,501,507 links (the gridpoint count is the number of gridpoint rows that `13_build_schema_prototypes.R` moves out of `Samples` in its gridpoint variant). It cannot show behaviour across the dateline.

## 1. What is in v1.0.0?

### File and storage

Measured by `01_inspect_v1_metadata.R` (header, PRAGMAs) and `06_scan_v1_full.R` (`dbstat`, 213 s):

- The file holds 110,036,815,872 bytes: 26,864,457 pages of 4,096 bytes. The free list is empty (0 pages), and `dbstat` finds 0.3 % unused space inside the pages of the link table and at most 0.7 % in any other table. A `VACUUM` would therefore reclaim almost nothing.
- The schema in the file is identical to `Data/SQL/make_tables.sql` on the `2.0.0` branch: 29 tables and 56 indexes. The file was last written by SQLite 3.46.0, in rollback-journal mode, and holds `sqlite_stat1` and `sqlite_stat4` statistics.

| Objects | Size (GB) | Share of the file |
| --- | ---: | ---: |
| `AbioticDataReference` (links) | 47.70 | 43.3 % |
| index on `AbioticDataReference.sample_ref_id` | 29.02 | 26.4 % |
| index on `AbioticDataReference.sample_id` | 27.41 | 24.9 % |
| links with both indexes | 104.13 | 94.6 % |
| `SampleUncertainty` with its index | 2.73 | 2.5 % |
| `AbioticData` with its two indexes | 0.49 | 0.4 % |
| everything else (26 tables, 51 indexes, the schema and statistics tables) | 2.69 | 2.4 % |

The link table costs 50.4 bytes per link with its two indexes (104.13 GB over 2,067,445,952 links). The gridpoints stored as ordinary rows take about 0.16 GB (0.15 %): 0.085 GB of `Samples` and its indexes, 0.064 GB of `DatasetSample` and 0.013 GB of `Datasets`. `dbstat` cannot split a table by row type, so these three are estimated from the gridpoint share of the rows (11.9 % of `Samples` and `DatasetSample`, 25 % of `Datasets`); the abiotic values, which belong only to gridpoints, are measured above (0.49 GB). The 14 unique indexes that duplicate an `INTEGER PRIMARY KEY` (for example `idx_samples_sample_id`) take 0.17 GB together (0.16 %); they are dead weight but not a size problem.

### Rows

Exact counts by `06_scan_v1_full.R`; the per-table row counts agree with the `sqlite_stat1` statistics and the maximum rowid of every table (`01_inspect_v1_metadata.R`).

| Table | Rows |
| --- | ---: |
| `AbioticDataReference` | 2,067,445,952 |
| `SampleUncertainty` | 88,423,000 |
| `Samples`, `DatasetSample` | 12,998,979 each |
| `TraitsValue` | 11,366,223 |
| `AbioticData` | 10,871,705 |
| `SampleTaxa` | 3,689,420 |
| `SampleReference` | 1,558,641 |
| `Datasets` | 426,225 |

| Dataset type | Source | Datasets | Samples | Distinct (longitude, latitude, age) |
| --- | --- | ---: | ---: | ---: |
| vegetation plot | sPlotOpen | 67,022 | 67,022 | 53,377 |
| vegetation plot | BIEN | 24,233 | 24,233 | 16,719 |
| fossil pollen archive | FOSSILPOL | 1,393 | 88,423 | 88,340 |
| traits | BIEN | 194,788 | 10,399,832 | 194,675 |
| traits | TRY | 32,342 | 876,656 | 22,876 |
| gridpoints | gridpoints | 106,447 | 1,542,813 | |

Trait samples are 98.4 % of the 11,456,166 non-gridpoint samples. Together the non-gridpoint samples sit at 373,225 distinct (longitude, latitude, age) positions, which is the unit the v1 linkage works on (in batches of 500: 747 batches).

### The plan's estimates, confirmed or corrected

| Plan estimate | Measured | Source |
| --- | --- | --- |
| about 11 M non-gridpoint samples | 11,456,166 | `06_scan_v1_full.R`, exact |
| about 1.6 M gridpoint samples of about 13 M | 1,542,813 of 12,998,979 (11.9 %) | `06_scan_v1_full.R`, exact |
| 15 to 20 linked cells per sample | median 18 to 22 cells by source (maximum 46) | `02_sample_v1_link_structure.R`, up to 1,000 drawn samples per source |
| up to 21 ages per sample | 11 ages for age-0 samples, 20 to 21 for fossil pollen | `02_sample_v1_link_structure.R`, drawn |
| links per sample | mean 207.9, median 198, 1 % above 357, maximum 800, over 9,944,505 linked samples | `06_scan_v1_full.R`, exact |
| CHELSA cell spacing | 360° / 1,728 = 0.2083°; the grid has 1,728 × 835 = 1,442,880 cells; stored coordinates are rounded to 0.01°, so neighbours sit 0.20 or 0.21° apart | v1.1.0 abiotic artefacts (`07_prepare_profiling_inputs.R`), `02_sample_v1_link_structure.R` |
| gridpoint ages in `vec_age` | 37: 0 to 18,000 years by 500 | v1.1.0 abiotic artefacts, and the gridpoint samples in v1.0.0 |

The v1 gridpoint stage considered 1,442,880 cells × 37 ages = 53,386,560 candidate gridpoint samples and stored only those that received at least one link: 1,542,813 samples in 106,447 cells (7.4 % of the cells). Each stored gridpoint sample carries 1 to 78,797 links (median 31, mean 1,340), because one gridpoint serves every sample near it.

### Natural keys, distances and integrity

- `Samples.sample_name` and `Datasets.dataset_name` have no duplicates and no missing values (exact). UNIQUE constraints on both would hold for the v1 content.
- Both distance columns of all 2,067,445,952 links are stored as INTEGER; `distance_in_km` runs from 0 to 49 and `distance_in_years` from 0 to 5,000, with no missing keys (exact, 1,146 s). The km value is the geodesic distance truncated by `as.integer()` in `add_abiotic_data_ref()`, so 49.9 km is stored as 49.
- `PRAGMA foreign_key_check` finds no violation (exact, 325 s).
- Every gridpoint sample has abiotic values and at least one link. `AbioticData` holds 7 climate variables for all 1,542,813 gridpoint samples (one variable for 1,541,019) and the soil variable for 73,808 samples.

### Content gaps found on the way (for the producer lanes)

- 1,511,661 non-gridpoint samples (13.2 %) have no links. All 1,109,969 unlinked BIEN trait samples belong to datasets with a missing coordinate. Of the 401,692 unlinked TRY samples, 392,809 have a missing coordinate; the other 8,883 have coordinates that include impossible values (the largest stored latitude is 5,659,383,125).
- 238,777 of the 10,399,832 BIEN trait samples (2.3 %) have no trait value; every TRY trait sample has one. The trait samples carry 11,366,223 values over 11,037,711 samples.
- `SampleTaxa` lists the same taxon more than once for the same sample in 189,639 (sample, taxon) pairs, which hold 647,816 of its 3,689,420 rows: 179,742 pairs in BIEN vegetation plots and 9,897 in sPlotOpen plots. In sPlotOpen most of these pairs carry different values (15,888 distinct values over 9,897 pairs); in BIEN, 179,742 pairs carry 98,031 distinct non-missing values. Another 1,678 rows have a missing sample or taxon id (`15_check_v1_schema_candidates.R`, exact). Whether the repeated pairs come from the sources or from the matching of taxon names during the import was not checked.
- 514 TRY datasets have a coordinate outside −180 to 180 or −90 to 90, and 4,410 TRY and 212 BIEN datasets have a missing coordinate (`15_check_v1_schema_candidates.R`, exact).

## 2. Where does the time go?

### How the v1 build was profiled

The v1 gridpoint stage (`R/02_Main_analyses/06_Create_gridpoints.R`) and one current-climate import (the bio1 call of `07_Import_chelsa_neo_climate_data.R`) were run with the v1 functions unchanged, on disposable copies of the subset in the state just before the stage, for three nested boxes (`07_prepare_profiling_inputs.R`, `08_profile_v1_gridpoints.R`): Kenai (longitude −152 to −148, latitude 59 to 62), a core box (−165 to −135, 56 to 70) and the full subset box. The inputs are the exact v1.1.0 abiotic artefacts the stage downloads, read from the local VegVault-abiotic_data checkout (they are legacy `qs` files, so they were read with R 4.5.1 by `07a_read_v1_abiotic_inputs_legacy.R`). Base `trace()` logged a timestamp before every top-level step of 19 v1 functions and at their exit, with the row counts of their data frames (about 0.6 ms per event, about 1.3 s in the full-box run); `Rprof()` sampled the whole run as a cross-check. Each run reproduced the v1.0.0 links of its box exactly (same sample and gridpoint pairs, same km and years, no row differing), so the profile is of the code that built v1.0.0.

Three deviations from the real build are measured separately: the candidate gridpoints of a box run are the cells of the box plus the margin, not the whole globe (`09_profile_v1_global_batches.R` times three real batches against the whole-globe table); the box databases hold only the datasets of the box, so the whole-table reads read small tables (`10_benchmark_link_writes.R` measures read rates); and the inputs are local copies, not downloads.

Machine: Intel i9-13900KF (24 cores), 63.8 GB RAM, NVMe disks, Windows 11; R 4.6.2 single-threaded, RSQLite 3.53.3 (SQLite 3.53.3), dbplyr 2.6.0. Each run was done once. The first attempt of the full-box run failed with a SQLite "disk I/O error" at batch 10 when another lane's job exhausted the machine's memory; it was rerun after that job ended, and only the complete run is used.

### Measured on the subset

| Box | Sample positions | Batches | Gridpoint candidates | Candidate pairs | Links | Stage 06 (s) | bio1 import (s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Kenai | 722 | 2 | 23,902 | 855,235 | 7,418,132 | 44 | 11 |
| core | 3,737 | 8 | 420,912 | 5,013,281 | 24,485,129 | 260 | 13 |
| full subset box | 5,654 | 12 | 774,410 | 7,392,625 | 48,501,507 | 450 | 13 |

A sample position is a distinct (longitude, latitude, age); v1 links positions to gridpoints and then expands the links to every sample at the position. 32 to 34 % of the candidate pairs survive the 50 km and 5,000-year cut in all three boxes.

Where the 450 s of the full-box stage go (`08_profile_v1_gridpoints.R`, step totals):

| Step | Seconds | Share |
| --- | ---: | ---: |
| distance: one `geosphere::distGeo()` call per candidate pair through `purrr::pmap_dbl()` | 252 | 56 % |
| link writes in `add_abiotic_data_ref()` (`dplyr::copy_to()` into the indexed table) | 134 | 30 % |
| fine filter (`vctrs::vec_slice()` per position) | 15 | 3 % |
| duplicate test of the new links against the stored links | 11 | 3 % |
| building the link rows (joins to sample ids) | 10 | 2 % |
| coarse filter, on the box candidates only | 8 | 2 % |

At the whole-globe candidate table of v1 (53,386,560 rows), the coarse filter of one batch takes 23.7 to 30.0 s, against 0.3 to 1.7 s for the same batches with the box candidates, and gives the same links (`09_profile_v1_global_batches.R`, 3 batches). Most of that is fixed per batch: the last batch, with 154 positions, still takes 23.7 s, because every batch re-bins all 53 M candidates five times. Filtering the whole-globe table for the gridpoints to import adds 1.1 s per batch. Building and deduplicating the whole-globe candidates once takes 72 s and 17.4 GB of memory at peak.

Writing the 48,501,507 links of the subset in 12 batches (`10_benchmark_link_writes.R`):

| Write path | Seconds | Per link |
| --- | ---: | ---: |
| v1: `dplyr::copy_to()` with its defaults into the table with both indexes | 242 | 5.0 µs |
| the same with `analyze = FALSE` | 217 | 4.5 µs |
| `DBI::dbAppendTable()` into the table without indexes, then both indexes built | 11 + 22 = 33 | 0.68 µs |

With the indexes present, a batch of 4 M links took 9.7 s at the start and 19 to 24 s at the end, because index inserts slow down as the indexes grow; without them every batch took 0.9 to 1.0 s. One `ANALYZE` of the full link table takes 3.6 s. `dplyr::copy_to()` defaults to `analyze = TRUE`, so v1's `add_to_db()` runs `ANALYZE` on the target table after every write; only the v1 path left statistics behind. This is the default in dbplyr 2.6.0 (the 2.0.0 lockfile); the v1 lockfile does not record which dbplyr version built v1.0.0, so it is not confirmed for that build.

The one-off and per-batch reads named in the issue, measured in the full-box run (`08_profile_v1_gridpoints.R`; `Samples` grows from 154,069 to 233,786 rows during the run) and scaled to v1.0.0 by rows (`10_benchmark_link_writes.R` read rates):

| Read | Measured on the full subset box | At v1.0.0 size (extrapolated) |
| --- | --- | --- |
| collect of all non-gridpoint samples at the start of the stage (once) | 0.45 s for 154,069 samples | about 33 s for 11.46 M |
| `IN` query that skips already-linked samples (once) | 1.1 s for all 82,282 gridpoint ids of the subset | empty on a fresh build |
| `add_samples_id()`: all sample names, then all sample ids and names | 0.14 and 0.10 s per batch | about 7 and 3 s per batch |
| `add_to_db()` on `Samples`: whole table and duplicate test | 0.12 s per batch | about 5 s per batch |
| `add_abiotic_data_ref()`: all sample ids and names | 0.08 s per batch | about 3 s per batch |
| `add_dataset_sample()`: all dataset-sample pairs | 0.06 s per batch | about 2.5 s per batch |
| one `add_chelsa_neo_data()` call (bio1, the whole-globe input of 1,442,880 cells) | 12.7 s, of which 10.3 s nest and unnest the input | not extrapolated; fixed by the input size, plus the reads above |

The read rates are 1.75 to 5.1 M rows per second (for example 2.8 M rows per second for all columns of `Samples`); their sum per batch at v1.0.0 size is the "whole-table reads" term below.

### Extrapolated to the v1.0.0 build

`11_extrapolate_v1_gridpoint_stage.R` multiplies each measured unit cost by the matching v1.0.0 count from question 1: 373,225 sample positions in 747 batches, 2,067,445,952 links, and candidate pairs from a fit of pairs per position on the 12 full-box batches (1,018 for age-0 positions and 1,654 for fossil-pollen positions, R² = 0.9998), giving 436 M pairs. Every term is a **lower bound**: the unit costs were measured where the tables and indexes fit in memory, while the v1.0.0 link indexes (56 GB) do not, so index inserts and `ANALYZE` will be slower at full size. Not included: the 15 climate and soil imports of stages 07 to 09, `ANALYZE` of the other tables after their writes, and restarts.

| Term | Method | Hours (lower bound) | Share |
| --- | --- | ---: | ---: |
| `ANALYZE` of the link table after every batch | 0.074 µs per row read × 773 G rows read over 747 batches | 15.9 | 48 % |
| coarse filter on the whole-globe candidates | 27.1 s per batch × 747 | 5.6 | 17 % |
| whole-table reads of the writers | 21.4 s per batch at mean v1 table size × 747 | 4.4 | 13 % |
| distance, one call per pair | 34 µs × 436 M pairs | 4.1 | 12 % |
| link inserts into the indexed table | 5.0 µs × 2.07 G links | 2.8 | 9 % |
| fine filter | 2.6 ms × 373,225 positions | 0.3 | 1 % |
| filtering the whole-globe table for imports | 1.1 s × 747 | 0.2 | 1 % |
| building the whole-globe candidates (once) | measured at full size | 0.02 | 0 % |
| **total** | | **33.5** | |

The issue records that the last build spent about a week on gridpoint linkage. The lower bound of 33.5 h is a fifth of that; the gap is consistent with the disk-bound index work at full size and the terms not included, but it was not measured. Appending the links without indexes and building both indexes once would take about 0.4 h instead of the 18.8 h of the two write terms, by the same method.

### The estimated ranking compared with the measurements

| Rank | Estimated from static reading (issue) | Extrapolated to full size | Measured on the full subset box |
| ---: | --- | --- | --- |
| 1 | scalar `distGeo` via `pmap_dbl` | `ANALYZE` after every batch (not in the estimate) | distance |
| 2 | whole-table reads in every batch | coarse filter | link writes |
| 3 | coarse filter | whole-table reads | fine filter |
| 4 | fine filter | distance | duplicate test |
| 5 | index maintenance on every insert | index inserts | building link rows |
| 6 | one-off costs | fine filter | coarse filter (box candidates) |

Where they differ:

- The largest full-size term, `ANALYZE` after every batch, is missing from the estimate. It comes from the `copy_to()` default, not from VegVault code, and grows with the square of the number of links.
- The distance step leads at subset size but is fourth at full size: it scales with the number of candidate pairs, while `ANALYZE`, the coarse filter and the whole-table reads scale with the size of the whole database once per batch.
- The estimate of 4,500 to 9,000 candidates per position with 15 to 20 % surviving is too high on the first and too low on the second: v1 makes about 1,000 (age-0) to 1,650 (fossil pollen) candidate pairs per position, and 32 to 34 % survive.
- The fine filter and the one-off costs are small, as estimated.

## 3. How does vaultkeepr use the database?

### How the queries were collected

`12_profile_vaultkeepr_queries.R` exported the released vaultkeepr 0.1.0 (`origin/main`, commit `edf90b6`) with `git archive` and ran 11 workloads taken from the vaultkeepr vignettes against v1.0.0 (`12a_run_vaultkeepr_workload.R`). Each run was a fresh R child process that loaded the export with `pkgload::load_all()`. `open_vault()` opens a read-write connection, so the script built the same `vault_pipe` object around a `SQLITE_RO` connection instead. Every statement that reached SQLite was logged by tracing RSQLite's `result_create()` and `result_release()`. This captures everything vaultkeepr executes: the final query and every intermediate `collect()`, count and dbplyr column probe. `dplyr::show_query()`, which the issue suggests, shows only the final lazy query. Each workload ran 3 times, with the repetitions interleaved. Times are medians, with the range in brackets. Workload time is the wall time of the vaultkeepr pipe. Statement time runs from creating the result to releasing it, so it includes fetching the rows. Memory is the peak of R's heap from `gc()`, which leaves out SQLite's page cache. `EXPLAIN QUERY PLAN` ran on each of the 149 distinct statements of the first repetition, leaving out the probes. The machine is the one from question 2. The file-state check (section "How v1.0.0 was read") found v1.0.0 unchanged and identical to its question 1 baseline. The result tables were built from the saved statement logs by a second, reprocess-mode call of the script, because the first post-processing stopped on a regular-expression limit; no workload was rerun.

The workloads use every exported function except `open_vault()` (replaced as described above) and `select_taxa_by_id()` and `select_abiotic_var_by_id()`, the by-id twins of the by-name selectors used here. The boxes are the vignettes' boxes: western North America (longitude −116 to −114, latitude 44 to 46), Europe (14 to 16, 44 to 46) and South America (−61 to −59, −16 to −14).

### Measured on v1.0.0

| Workload | Box | Result rows | Seconds | Statements | Share of time in the reference check | Peak R memory (MB) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `explore_vault()` | | | 0.01 | 1 | | 141 |
| a01: fossil pollen of *Betula* (genus), 0 to 8,000 years | western North America | 2 | 67.3 (65.6–74.6) | 50 | 83 % | 214 |
| a01: taxon names of the same selection | western North America | 16 | 9.4 (8.9–9.5) | 26 | | 214 |
| a02: vegetation plots with bio1 of the nearest gridpoint | Europe | 609 | 6.9 (6.7–7.5) | 63 | 1 % | 222 |
| a02: the same with the mean of all linked gridpoints | Europe | 609 | 9.3 (9.3–9.9) | 63 | 25 % | 223 |
| a03 as in the vignette: pollen and plant-height traits, box applied only to pollen | South America | 227,130 | 695 (692–750) | 65 | 77 % | 4,813 |
| a03 with the box applied to traits too | South America | 23 | 98.1 (96.4–102.8) | 65 | 78 % | 214 |
| a04: everything in a box, as flat rows | western North America | 11,282,785 | 227 (226–240) | 38 | 72 % | 3,042 |
| a05: references of plots and gridpoints | Europe | 16 | 4.1 (4.0–4.1) | 52 | | 214 |
| a06: age uncertainty of fossil pollen samples | western North America | 43 | 44.7 (44.6–46.7) | 20 | | 215 |
| a07: classification table of the whole database | none | 46,682 | 33.8 (33.2–36.6) | 21 | | 214 |

Every repetition sent 464 statements. 315 of them are dbplyr column probes (`WHERE (0 = 1)`) and table listings, which took 1.0 to 1.1 s in total per repetition. The results of a03 as in the vignette and a04 take 1,617 and 1,897 MB in R.

### Where the time goes

Five query shapes account for almost all of the time. None of them is a missing index. All five are vaultkeepr code, not schema.

1. **The mandatory-reference check in `extract_data()`** takes 831 s of the 1,196 s of a repetition (70 %): 72 to 83 % of the four extract workloads outside a02, against 1 and 25 % in the two a02 workloads. `extract_data()` defaults to `check_mandatory_references = TRUE` and calls `get_references()`. For each reference type whose id column is in the selection (up to 8), `get_references()` re-runs the whole lazy query as `SELECT DISTINCT <id>`. It then sends the ids back to SQLite as a literal `IN` list. The result only decides whether a warning is shown, and with `verbose = FALSE` the warning is not shown at all. In a01, six re-runs of 9 to 10 s each produce a 2-row result. In a03 as in the vignette and in a04, one of the `IN` lists holds about 11.3 M sample ids, about 100 MB of SQL text per statement, and SQLite takes about 4 to 5 s to run each one. By subtraction, without the check a01 would take about 11 s, a03 as in the vignette about 159 s, a03 boxed about 21 s and a04 about 65 s. These are derived, not measured.
2. **Classified taxa are computed for the whole database.** `get_taxa(classify_to = "genus")` joins a subquery that SQLite materialises in full: it scans `TaxonClassification` and reads `SampleTaxa` through its `taxon_id` index for every taxon, all before the box filter applies. Each evaluation takes about 9 s, even for a box with a handful of samples; a01's taxon names, a single statement, take 9.0 s for 16 names. `get_traits(classify_to = "genus")` does the same with `TraitsValue`.
3. **The box filter is a `CASE` expression.** `select_dataset_by_geo()` computes a `keep` column with `CASE WHEN … THEN 0 ELSE 1 END` and filters on it. No index can serve that, so the plans read all of `Datasets` (426,225 rows), all datasets of the selected types, or all of `DatasetSample`, and the coordinate index is never used. The filter also keeps every dataset whose type is not in `sel_dataset_type` (by default vegetation plots, fossil pollen and gridpoints), wherever it lies. So in a04 and in a03 as written in the vignette, all 227,130 trait datasets in the world (11.3 M samples) pass a 2° box. That makes these two the slowest workloads and the only ones with large results. With the box applied to traits as well, the a03 query returns 23 rows in 98 s instead of 227,130 rows in 695 s.
4. **`get_age_uncertainty()` uses a correlated `EXISTS`.** SQLite scans all 88,423,000 rows of `SampleUncertainty` and runs the subquery for each row: 44.4 s for the 43 result rows. The 1.15 GB index on `SampleUncertainty.sample_id` is never used.
5. **`get_classification_table()` reads every sample's taxa** (`SELECT DISTINCT taxon_id` over all datasets and samples): 33.5 s. This is by design for a whole-database table.

The gridpoint links themselves are cheap to read. `get_abiotic_data()` reads `AbioticDataReference` through the index on `sample_id`: 0.04 to 0.07 s per statement for the nearest gridpoint, and 0.3 s per statement for the mean of all linked gridpoints, which adds a window function. Most of the 2.7 s that `get_abiotic_data()` takes in a02 goes to collecting the selection's sample ids, which is a consequence of the `CASE` filter.

### Indexes used, missing and dead weight

27 of the 56 indexes appear in at least one plan; the index-usage table written by `12_profile_vaultkeepr_queries.R` lists the workloads that use each one.

**Missing.** No plan builds an automatic index on a base table. All 94 automatic indexes in the plans are built on materialised subqueries of dbplyr's nested SQL, which no index in the schema can serve. The full scans of base tables are of three kinds:

- small lookup tables (`DatasetTypeID`, `DatasetSourceTypeID`);
- whole tables the query needs in full (`TaxonClassification`, `Traits`, `References`);
- two scans an existing index could replace if the query shape allowed it: `Datasets`, because of the `CASE` filter, and `SampleUncertainty`, because of the correlated `EXISTS`.

For these workloads no index is missing; the gains are in the query shapes.

**Dead weight.** The 17 indexes that are neither primary-key duplicates nor used by any plan take 31.0 GB (sizes from the `dbstat` pass of question 1):

| Unused index | Size (GB) | Why it is unused |
| --- | ---: | --- |
| `AbioticDataReference.sample_ref_id` | 29.02 | vaultkeepr reads links only by `sample_id` |
| `SampleUncertainty.sample_id` | 1.15 | the correlated `EXISTS` scans the table instead |
| four on `TraitsValue` (`dataset_id`, `sample_id`, `trait_id`, `dataset_id + sample_id + taxon_id`) | 0.62 | traits are reached through the `taxon_id` index only |
| `Samples.sample_size_id` | 0.12 | the lookup table is joined by its primary key |
| `AbioticData.abiotic_variable_id` | 0.11 | values are reached by `sample_id`, and the variable is filtered afterwards |
| `Datasets (coord_long, coord_lat)` | 0.01 | the `CASE` filter |
| four on `TaxonClassification`, and the `reference_id` indexes of `TaxonReference`, `TraitsReference` and `SamplingMethodReference`, and `Traits.trait_domain_id` | < 0.01 | whole-table scans, or lookups in the other direction |

Of the 14 unique indexes that duplicate an `INTEGER PRIMARY KEY` (0.17 GB), 12 never appear in a plan. The other two, `idx_samples_sample_id` (25 plan steps) and `idx_datasets_dataset_id` (3), are used as narrow covering indexes for `(id, rowid)` lookups that the table's own b-tree would otherwise serve. Dropping them cannot change results, but it slows the reference check of `extract_data()` (question 4, "The index set").

"Unused" means unused by these 11 workloads in vaultkeepr 0.1.0. It says nothing about the build or the validation; whether they need the `sample_ref_id` index on the link table (for example for `foreign_key_check`) is part of questions 6 and 7.

### Which schema changes need a vaultkeepr change

vaultkeepr 0.1.0 names 15 tables directly in `dplyr::tbl()` calls and reaches the reference and lookup tables through table names held in variables. It selects and joins by column name and never by rowid or index name. On that basis:

| Schema change (question 4) | Effect on vaultkeepr 0.1.0 | vaultkeepr change? |
| --- | --- | --- |
| drop the 14 primary-key duplicate indexes | none; index names never appear in vaultkeepr | no |
| drop the `sample_ref_id` index of the link table | none for reading | no |
| make the box filter or `get_age_uncertainty()` use an index | the index exists already; only a change of the query shape lets SQLite use it | yes |
| links per unique (coordinate, age) with a sample-to-tuple map | `get_abiotic_data()` reads `AbioticDataReference` by `sample_id` with `sample_ref_id`, `distance_in_km` and `distance_in_years` | yes, unless a view keeps the old table name and columns |
| a dedicated gridpoint table | vaultkeepr finds gridpoints as `Datasets` of type `gridpoints` with ordinary `Samples`, and joins `AbioticData` through them | yes, unless views keep the old shape |
| `WITHOUT ROWID` tables and composite primary keys | none; no rowid is used | no |
| integer km and years | already `INTEGER` in v1.0.0 | no |
| integer ages | same column names; `age` arrives in R as integer instead of double | none found by reading the code; to confirm with the vaultkeepr tests on the prototype |
| `UNIQUE` natural keys and `CHECK` constraints | none; vaultkeepr only reads | no |
| version metadata in `version_control` | 0.1.0 does not read it. The unreleased L7 branch (`OndrejMottl/issue76` in vaultkeepr) reads `SELECT version FROM version_control` and takes the last row returned, so new columns are safe, but the 2.0.0 row must come last in rowid order, or vaultkeepr must order explicitly | coordinate with L7 |
| fix the misspelt `TraitsDomain.trait_domanin_description` | vaultkeepr never names it, but the column reaches the user's table from `extract_data()` | no code change; a change users will see |

The query-shape findings above (the reference check, the whole-database classification, the `CASE` box filter and its handling of unselected types, and the correlated `EXISTS`) are vaultkeepr changes. They are worth more than any schema change measured so far, and they are reported to lane L7 through Ondřej.

## 4. Schema candidates

### How the candidates were measured

`13_build_schema_prototypes.R` built seven schema variants from the rows of the regional subset into new files. The variants are cumulative, so each difference has one cause:

| Variant | Change from the previous one | Indexes |
| --- | --- | ---: |
| `v1` | the v1 schema (`Data/SQL/make_tables.sql`), indexes created after loading | 56 |
| `no_pk_duplicates` | without the 14 unique indexes that duplicate an `INTEGER PRIMARY KEY` | 42 |
| `lean_indexes` | also without 15 indexes that no plan of question 3 used and `idx_sampletaxa_sample_id`, the leading column of another index; the unused indexes on `SampleUncertainty.sample_id` and the `Datasets` coordinates stay, because the query shapes vaultkeepr should send would use them | 26 |
| `without_rowid` | 13 junction and value tables as `WITHOUT ROWID` tables with a composite primary key; indexes that start with the first key column are dropped | 14 |
| `tuple_links` | links once per (longitude, latitude, age) position: `Positions`, `SamplePosition` (the position of each sample) and `PositionLink`, with a view `AbioticDataReference` that returns the v1 rows | 14 |
| `gridpoint_tables` | `tuple_links` with the gridpoints in their own tables (`GridpointCells`, `Gridpoints`, `GridpointValues`) instead of `Datasets` and `Samples` rows, and without their per-row references | 14 |
| `constraints` | `tuple_links` with `UNIQUE` and `NOT NULL` on sample and dataset names and `CHECK` constraints on coordinates, link distances and `References.mandatory` | 14 |

The changes are SQL files in `R/Analyses/90_Database_research/Prototype_schemas/`; the script writes the composed schema of each variant to its run folder. Every build used the same settings (`journal_mode = OFF`, `synchronous = OFF`, `foreign_keys = OFF`, 1 GiB page cache; question 6 measures them one by one), copied each unchanged table in key order, created the indexes after loading and ran `ANALYZE`. Each variant was built 3 times, interleaved; times are medians with the range in brackets. The positions and position links were derived from the v1 links of the subset in temporary tables (13 s per build). This step is reported apart from the build time, because a 2.0.0 build would compute links per position directly. The subset was attached read-only (`mode=ro`) and was unchanged afterwards.

On the kept files, every table or view that has the same name as a subset table held the same rows: equal counts for all of them, and `EXCEPT` in both directions empty for the rewritten ones. In particular, the view `AbioticDataReference` of `tuple_links` and `constraints` returns exactly the 48,501,507 links of the subset. `gridpoint_tables` holds the subset rows minus the 3,767 gridpoint datasets and 82,282 gridpoint samples, and its own checks confirm that every gridpoint cell, gridpoint and value is in the new tables.

The variants were then read in three ways, all read-only:

- `12_profile_vaultkeepr_queries.R` ran the 11 workloads of question 3 with vaultkeepr 0.1.0 on each variant, 3 times each, with the box of every workload set to longitude −150 to −148 and latitude 68 to 70.
- `14_query_schema_prototypes.R` timed benchmark queries 5 times each, interleaved over the variants: link reads, the vaultkeepr 0.1.0 statements for the nearest gridpoint and for `get_age_uncertainty()`, rewritten versions of the slow ones, and `foreign_key_check`, `quick_check` and `integrity_check` once per variant. Every result was fingerprinted; the results were identical across variants except where `gridpoint_tables` no longer counts gridpoints as datasets.
- `15_check_v1_schema_candidates.R` measured on v1.0.0 (read-only, 126 s, file unchanged) what the subset cannot show: the positions and position links at full size, whether all samples of a position have the same links, and whether the candidate keys hold.

`16_project_schema_sizes.R` projects the subset sizes to v1.0.0. For every table except the link tables, it takes the measured v1.0.0 size of the table with its indexes (question 1) times its size ratio between the variant and `v1` on the subset. For the link tables, it multiplies bytes per row on the subset by the v1.0.0 row counts. The per-row method gives 101.4 GB for the v1 link table with its indexes, against 104.1 GB measured: the v1 build wrote its indexes in random order, which leaves pages less full. The projections below therefore take the v1 layouts from the measured size by ratio, and the position tables per row. `gridpoint_tables` moves rows between tables, so it is not projected.

The builds and benchmarks ran on the machine of question 2 (24 cores, 63.8 GB of RAM). The subset files fit in its memory, while the v1.0.0 link indexes alone (56 GB) do not, so subset query times show the work a plan does, not the disk reads it would need at full size.

### Results of the prototypes

| Variant | File on the subset (MB) | Build on the subset (s) | Projected to v1.0.0 (GB) | `integrity_check` on the subset (s) | vaultkeepr 0.1.0 workloads |
| --- | ---: | ---: | ---: | ---: | --- |
| `v1` | 2,522 | 27.4 (26.9–39.8) | 110.0 (measured) | 23.5 | all 11 |
| `no_pk_duplicates` | 2,519 | 27.6 (27.6–31.1) | 109.9 | 23.6 | all 11 |
| `lean_indexes` | 1,830 | 14.6 (14.4–14.9) | 79.5 | 10.2 | all 11 |
| `without_rowid` | 1,078 | 15.4 (15.0–15.5) | 47.1 | 2.9 | all 11 |
| `tuple_links` | 128 | 2.3 (2.2–2.3) | 5.3 | 0.45 | all 11 |
| `gridpoint_tables` | 123 | 2.2 (2.2–2.9) | not projected | 0.43 | 8 of 11 |
| `constraints` | 136 | 2.3 (2.3–3.3) | 5.7 | 0.50 | all 11 |

Build time is the sum of table creation, loading, indexes, views and `ANALYZE` on the subset; it is not extrapolated here (question 5). In the six variants that keep gridpoints as datasets, the vaultkeepr workloads returned the same rows as on `v1`, and the total time per repetition stayed between 27.4 and 29.6 s. The reference check of `extract_data()` (question 3) dominates that total in every variant.

### Links per position

At v1.0.0 size, the 9,953,388 non-gridpoint samples with coordinates and age sit at 373,011 positions, which hold 94,918,432 position links. That is 22 times fewer rows than the 2,067,445,952 sample links (`15_check_v1_schema_candidates.R`, exact). The layout is lossless only if every sample of a position has the same links. That holds exactly on the subset (the `EXCEPT` check above). On v1.0.0 it held for all 2,000 positions drawn from the 212,171 positions with two or more samples, comparing 9,446 samples. This follows from the v1 code, which links positions and then copies the links to every sample at the position.

- **Size.** The link storage falls from 104.1 GB to 2.0 GB projected (1.83 GB `PositionLink`, 0.12 GB `SamplePosition`), and the whole file from 110 GB to 5.3 GB. Question 5 measured it at full size: the four position tables of the 2.0.0 links (95.3 M links, with `Positions`, `SamplePosition` and `Gridpoints`) take 2.12 GB.
- **Build.** The build writes 95 M rows instead of 2.07 G and needs no secondary index on them. On the subset the three position tables take 1.0 s to load, against 4.8 s to load the v1 link table and 18.6 s to build its two indexes.
- **Queries.** Through the view, vaultkeepr 0.1.0 reads the same links as fast as before. The links of the 326 plots in the box (128,403 rows) take 0.046 s against 0.048 s, and the nearest-gridpoint statement 0.039 s against 0.040 s. Reading all 48.5 M links through the view takes 1.32 s against 1.64 s from the v1 table. The view is resolved by the primary key of `SamplePosition` and then of `PositionLink`. The native join without the view takes 0.055 s.
- **vaultkeepr.** None, as long as the view keeps the name and columns of `AbioticDataReference`.

### A dedicated gridpoint table

Gridpoints as `Datasets` and `Samples` rows take about 0.16 GB of v1.0.0 (question 1). Their per-row references add 1,542,813 of the 1,558,641 `SampleReference` rows (99.0 %) and 106,447 of the 107,832 `DatasetReferences` rows. Every one of them names the same reference, which the gridpoint data source and source type already carry. All gridpoint names can be rebuilt from coordinates and age, and all gridpoint ages are whole numbers (`15_check_v1_schema_candidates.R`, exact). On the subset, dedicated tables save 4.9 MB of 128 MB (4 %).

The cost is in vaultkeepr 0.1.0. It finds gridpoints as datasets of type `gridpoints`, so:

- `get_abiotic_data()` stops in both a02 workloads and in a05, because the selection holds no gridpoints and the `AbioticData` table it checks for is gone;
- a04 returns 1,852 fewer rows without any message, because the gridpoints of the box are no longer datasets.

The bio1 values of the linked gridpoints take 0.020 s through the new tables, the same as through `AbioticData` in `without_rowid`.

### `WITHOUT ROWID` tables and composite primary keys

On v1.0.0, every candidate key holds except one. No duplicate and no missing value exists in the keys of `DatasetSample`, `SampleReference`, `SampleUncertainty`, `AbioticData`, `TraitsValue`, `TaxonClassification` and the eight reference junction tables (`15_check_v1_schema_candidates.R`, exact). `AbioticDataReference` was not grouped (2.07 G rows), but its key is the key of `PositionLink` in the per-position layout. The exception is `SampleTaxa`, with 189,639 repeated (sample, taxon) pairs and 1,678 rows with a missing id (section 1, content gaps); it stays a rowid table until the import resolves them.

- **Size.** On top of `lean_indexes`, the file shrinks from 1,830 to 1,078 MB on the subset (−41 %), and the projection from 79.5 to 47.1 GB. Without the per-position layout, the link table alone would still take 43.8 GB.
- **Build.** About the same (15.4 against 14.6 s): loading is slower (13.2 against 5.2 s; the link table alone 12.2 against 4.8 s), because the key is built while the rows arrive, but almost no index is left to build.
- **Queries.** Reads by the first key column are faster. The bio1 values of the box plots take 0.020 s against 0.051 s, and the vaultkeepr 0.1.0 age-uncertainty statement 0.72 s against 0.95 s. `integrity_check` takes 2.9 s against 10.2 s.
- **vaultkeepr.** None; vaultkeepr never uses rowids.

### Integer distances and compact ages

The two distance columns are already `INTEGER`. The type probes of `13_build_schema_prototypes.R` confirm how km is stored: for all 2,469,631 position links of the subset, the stored km equals the geodesic distance from `geosphere::distGeo()` in metres, divided by 1,000 and rounded down. 80,512 of them (3.3 %) lie between 49 and 50 km and are stored as 49. On the subset, the position links take 47.7 MB with integer km, 52.1 MB (+9 %) with integer metres, and 67.6 MB (+42 %) with real km. Storing metres would keep the distance to the metre for 0.17 GB more at v1.0.0 size, projected per row.

Ages cannot become integers: 27,562 of the 88,423 fossil pollen sample ages on v1.0.0 have a fractional part. Every other age is a whole number (`15_check_v1_schema_candidates.R`, exact). It would also save nothing. The ages of the subset take 2.52 MB both as `REAL` and as `INTEGER`, because SQLite stores whole-number `REAL` values as integers on disk. No vaultkeepr change is needed either way.

### Unique natural keys

v1.0.0 has no repeated or missing sample or dataset name (question 1). `UNIQUE` on `Samples.sample_name` adds an 8.0 MB index on the subset, which is 0.43 GB at v1.0.0 size, projected by ratio. The build time does not change measurably (2.3 s in both `tuple_links` and `constraints`). Composite keys on the junction and value tables come with `WITHOUT ROWID` above. vaultkeepr only reads, so it needs no change.

### `CHECK` constraints for units and ranges

The constraints prototyped are the documented ranges: coordinates within −180 to 180 and −90 to 90, link distances within the link rule (0 to 50 km, 0 to 5,000 years), and `References.mandatory` as 0 or 1. The subset passed all of them, and they cost no measurable build time. On v1.0.0, the 514 TRY datasets with coordinates out of range would fail the coordinate check (section 1), so a 2.0.0 import must drop or correct them first. `References.mandatory` holds only the integers 0 and 1. Unit constraints were not prototyped: the trait units belong to the unit contract of lane L6 (`TraitsDomain.trait_unit` on `OndrejMottl/issue76`). Which constraint belongs in the schema and which in the validation stage is question 7.

### The index set

- **Primary-key duplicates.** Dropping the 14 changes the size by 0.2 GB. On the subset, it slows a04 from 1.59 to 1.97 s and a07 from 0.36 to 0.46 s, the same in every repetition. All of the extra time is in the reference check of `extract_data()`: its `DISTINCT` re-runs read the narrow `idx_samples_sample_id` instead of the whole `Samples` table. The 12 other duplicates are never used. Keep `idx_samples_sample_id` and `idx_datasets_dataset_id` (they can be renamed to say what they are for) until vaultkeepr drops the reference re-runs, and drop the other 12.
- **Unused indexes.** Dropping the 15 unused indexes and the prefix duplicate takes the projection from 109.9 to 79.5 GB, nearly all of it the 29.0 GB `sample_ref_id` index. It halves the index time on the subset (19.3 to 8.0 s) and `integrity_check` (23.6 to 10.2 s), and the vaultkeepr workloads do not slow down.
- **Indexes kept for the fixed query shapes.** A plain `IN` filter uses the index on `SampleUncertainty.sample_id` and returns exactly the 45,000 rows of the vaultkeepr 0.1.0 statement, in 0.013 s instead of 0.96 s. A plain `BETWEEN` box filter uses the coordinate index and returns exactly the datasets of the `CASE` filter. The subset has too few datasets to time it (0.4 against 0.9 ms). In `without_rowid`, the primary key of `SampleUncertainty` replaces its index.
- **Indexes to add.** None for vaultkeepr 0.1.0 (question 3). With per-position links, nothing reads links by gridpoint, so no index on `PositionLink.sample_ref_id` is needed. Whether validation needs one is question 7.

### A version metadata hook

P4 has to check that the version row carries the producer tags and commit SHAs of the build and that they equal the pins in the build manifest. The v1 `version_control` table has no place for them. The candidate keeps `version_control` with one row per version, written in the order of `database: versions` in `config.yml`, and makes `version` `NOT NULL UNIQUE`. It adds build columns (`build_profile`, `git_commit`, `manifest_sha256`; empty for the earlier versions) and a table `BuildProducers` (`version_id`, `producer`, `tag`, `commit_sha`) with one row per producer pin.

The version reader `detect_vegvault_version()` of the vaultkeepr branch `OndrejMottl/issue76` (commit `74d7a8f`) was run on three small files (`14_query_schema_prototypes.R`):

| Version table | Rows written in the order | Returned |
| --- | --- | --- |
| v1 `version_control` | 0.0.2, 0.0.3, 0.0.4, 1.0.0, 2.0.0 | 2.0.0 |
| candidate with build columns and `BuildProducers` | 0.0.2, 0.0.3, 0.0.4, 1.0.0, 2.0.0 | 2.0.0 |
| v1 `version_control` | 2.0.0, 0.0.2, 0.0.3, 0.0.4, 1.0.0 | **1.0.0** |

New columns and tables do not disturb the reader. But it returns the last row of an unordered query, so it gives the wrong version as soon as the 2.0.0 row is not written last. This is a vaultkeepr change for lane L7: order by `id`, or take the highest version. The schema side needs no vaultkeepr change.

## 5. Build engines

### How the engines were compared

`17_benchmark_build_engines.R` built the same output from the regional subset with three engines, each run in a new R process (`17a_run_build_engine.R`):

- **R in memory** (`r_memory`): dplyr computes positions and links, chunk by chunk in memory, then writes everything into a new SQLite file in one transaction (`journal_mode = OFF`, `synchronous = OFF`).
- **Incremental SQLite** (`sqlite_incremental`): the same R code, but each chunk of links is written in its own transaction (WAL, `synchronous = NORMAL`) with a row in a `BuildChunks` table. Every later step records itself in `BuildSteps`, so a stopped run resumes where it stopped.
- **DuckDB** (`duckdb`): everything in DuckDB SQL (DuckDB 2.0.0, with its `spatial` extension for the geodesic distance, 8 threads, 16 GB memory limit), written into the SQLite file through DuckDB's `sqlite` extension. The R package and both extensions were installed outside the project library: the package into a research folder, and the extensions from the official DuckDB repository.

Every engine computes the same output, in the layout of question 4 with a simple gridpoint table:

- **Positions:** the distinct (longitude, latitude, age) of the non-gridpoint samples, numbered in that order.
- **Links:** every gridpoint within 50 km (geodesic, WGS84) and 5,000 years of a position, under the 2.0.0 rule. The candidate cells come from a window that widens with latitude, covers the poles and wraps at the dateline; the exact distance then decides. The distance is computed once per position and cell, not once per gridpoint, and km and years are stored rounded down, as in v1. The gridpoint id is derived from the cell number and the age number, so no id depends on the order of the work.
- **Gridpoints:** the linked gridpoints, and the bio1 value of each linked gridpoint of age 0. Only bio1 at age 0 is included, because the other climate values exist only in legacy `qs` files that R 4.6 cannot read.
- **Copies:** the other subset tables without their gridpoint rows.
- **Indexes and `ANALYZE`:** the question 4 index set plus the two primary-key duplicates that vaultkeepr's reference check uses, created after loading.

The candidate cells are the global CHELSA grid (1,442,880 cells, 37 ages), so the fixed cost of the inputs is already at full size.

Each engine ran 3 times, interleaved; times are medians with the range in brackets, and memory is the peak working set of the process. Three extra runs tested whether the ids depend on the order of the work: `r_memory` and `sqlite_incremental` with the chunks in reverse order, and `duckdb` with 1 thread instead of 8. A resume test let `sqlite_incremental` kill its own process in the middle of the sixth chunk, with half of that chunk written and not committed, and then restarted it. Every table of every output was fingerprinted (row count and a hash of the sorted rows) and compared with the first `r_memory` run. All 416 table comparisons of the 13 outputs were identical, and every output passed `quick_check`. The subset was opened read-only and was unchanged. The machine is the one of question 2.

### The 2.0.0 links on the subset

The 2.0.0 rule gives 2,538,032 position links on the subset, against 2,469,631 under v1. `19_compare_links_with_v1.R` matched them by position, gridpoint coordinates and age:

- **v1 links:** all 2,469,631 are found, with the same km and the same years.
- **Additional links:** the 68,401 links that only the 2.0.0 rule finds (2.8 %) belong to 1,300 positions, all north of 63.9°. Each of them is more than 1° of longitude away from its position, beyond the v1 search window. These are the links that v1 lost at high latitude (linkage bug a in VegVault issue 87).

The subset does not reach the dateline, so bug (b) is not tested here.

### Results of the engines

| Engine | Build on the subset (s) | Peak memory on the subset (MB) | Projected at v1.0.0 size (min) | Ids independent of the order of work | Resumes after a crash |
| --- | ---: | ---: | ---: | --- | --- |
| `r_memory` | 5.1 (5.0–5.2) | 563 | 3.6 | yes (reverse chunks) | no; reruns |
| `sqlite_incremental` | 4.2 (4.2–4.2) | 471 | 2.9 | yes (reverse chunks) | yes (killed mid-chunk, resumed, identical output) |
| `duckdb` | 4.0 (3.9–4.0) | 497 | 2.4 | yes (1 or 8 threads) | no; reruns |

Build time is the sum of the timed steps, from reading the inputs to `ANALYZE`, without starting R (about 0.8 s more per process).

Where the time goes on the subset, and projected to v1.0.0 size (`18_extrapolate_build_engines.R`):

- **R in memory:** the links take 1.13 s (42 s projected). Reading the copied tables takes 1.28 s (53 s), and writing all 5.9 M rows 1.93 s (81 s).
- **Incremental SQLite:** the links take 2.08 s (78 s projected), because each chunk is its own WAL transaction. The later steps take 0.97 s (43 s).
- **DuckDB:** it computes the links in 0.36 s with 8 threads (13 s projected), but writing through its `sqlite` extension is the slowest write path: 2.52 s (105 s).

In every engine, writing dominates. The link computation is small once the distance is computed once per position and cell with one vectorised call. v1 made one `geosphere::distGeo()` call per candidate pair and gridpoint.

**Memory at v1.0.0 size.** `r_memory` holds 16.0 bytes per link and 17.8 bytes per copied row in R (measured with `object.size()`). For the 94.9 M links and 127.2 M copied rows of v1.0.0, that is 3.8 GB held before writing, on top of the 0.5 GB the process needs on the subset; transient copies while binding and writing could add up to the same again (not measured). `sqlite_incremental` holds only the positions, the samples and one chunk, so its memory barely grows with the database. `duckdb` stays under its 16 GB limit and spills to its working file (44.6 MB on the subset). All three fit the 64 GB of the build machine with a wide margin.

**How the projection was made, and its uncertainty.** Each step time on the subset is multiplied by the ratio of the count that drives it, at v1.0.0 size and on the subset. The counts are samples (×64.6), positions (×64.7), links (×37.4), copied rows (×41.4) and all rows written (×41.8), all measured (questions 1 and 4). This is linear, so the projection does not capture:

- index builds, which grow faster than linearly;
- output tables larger than the page cache;
- the 2.0.0 rule's extra links beyond the v1 link count used here (2.8 % on the subset, mostly at high latitude);
- positions at lower latitudes, which have fewer candidate cells than on the subset, so the link step there is probably cheaper.

The projections are therefore order-of-magnitude figures. Even five times slower, every engine would build the links and the database in under 20 minutes, against the v1 gridpoint stage's lower bound of 33.5 h (question 2).

### The link step at full size

`20_run_full_size_links.R` ran the link code of `r_memory` on all positions of v1.0.0 (read-only; the file was unchanged afterwards). It wrote `Positions`, `SamplePosition`, `PositionLink` and `Gridpoints` into a new file in one transaction and ran `ANALYZE`. The script is a copy of the benchmark code; run on the subset first, its four tables were identical to those of the benchmark's `r_memory` output.

| Step | Seconds | Rows |
| --- | ---: | ---: |
| read the non-gridpoint samples with coordinates and age from v1.0.0 | 36.8 | 9,953,388 |
| number the positions and build the search windows | 1.8 | 373,011 |
| compute the links (747 chunks of 500 positions) | 37.2 | 95,345,705 |
| find the linked gridpoints | 1.0 | 1,560,757 |
| write the four tables in one transaction | 35.0 | 107,232,861 |
| `ANALYZE` | 5.5 | |
| **whole run, including starting R** | **124** | |

The process peaked at 6.0 GB of memory; the links alone took 1.53 GB in R (16.0 bytes per link, as on the subset). The file of the four tables takes 2.12 GB. The measured steps agree with the projection of question 5 within a factor of two. Computing the links took 37 s (42 s projected). Writing took 0.33 µs per row, as on the subset. Reading the samples took 37 s against 20 s projected, because v1.0.0 is read cold from a 110 GB file.

**The 2.0.0 link count.** The 2.0.0 rule gives 95,345,705 position links, 427,273 (0.45 %) more than the v1 rule for the same positions (94,918,432, question 4). The linked gridpoints are 1,560,757, against 1,542,813 gridpoint samples in v1.0.0.

All 373,011 positions get links except 477, which are among the 478 positions of the 8,883 TRY samples with impossible coordinates (section 1). The 478th has a longitude beyond 180° and a valid latitude, and the dateline wrap gave it 176 links that should not exist. The 2.0.0 import must reject impossible coordinates before linking, as the `CHECK` constraints of question 4 would.

**Against v1, at full size.** For 3,000 drawn positions, the v1 links of each position (those of its lowest sample id) were compared with the 2.0.0 links:

| Draw | Positions | v1 links | Found with the same km and years | Links only in 2.0.0 | Why v1 missed them |
| --- | ---: | ---: | ---: | ---: | --- |
| random | 2,000 | 498,701 | 498,701 | 1,764 (0.4 %) | more than 1° of longitude away |
| within 1.5° of the dateline | 500 | 10,146 | 10,146 | 5,502 (54 %) | across the dateline |
| north of 75° or south of −75° | 500 | 65,384 | 65,384 | 47,520 (73 %) | more than 1° of longitude away |

The 2.0.0 code reproduces every v1 link, adds only links that v1's window could not see, and fixes both linkage bugs of the issue. The effect is small on average but large near the dateline and the poles, where v1 lost 35 % and 42 % of the links.

### Fit with `{targets}`

All three engines end in one SQLite file, which `{targets}` tracks through the build manifest rather than by hashing it.

- **R in memory** fits best. Each chunk of links can be a dynamic branch whose result `{targets}` stores (1.5 GB of links in R at v1.0.0 size, less once compressed in the store). A failed or changed build then reruns only the chunks it needs, and the deterministic ids make the result independent of which chunks reran. A final target bulk-loads the file and writes the manifest. This gives the resuming of `sqlite_incremental` without keeping state inside the database.
- **Incremental SQLite** resumes inside one target. That duplicates what `{targets}` already does, and it leaves a partial database after a failure that the pipeline must either resume or delete on purpose.
- **DuckDB** keeps its intermediate tables in a working file outside the target store. Its extensions are downloaded at run time and are not pinned by `renv`. DuckDB 2.0 also changed the axis order of `ST_Distance_Spheroid()` and refuses to run until it is set, which shows the upgrade risk of that path.

## 6. Bulk-load practice

### How it was measured

`21_benchmark_bulk_load.R` loaded the full-size position tables written by the full-size link run of question 5 into new SQLite files: `Positions` (373,011 rows), `Gridpoints` (1,560,757), `SamplePosition` (9,953,388) and `PositionLink` (95,345,705), 107.2 M rows in all. The subset fits in memory and would hide the cost of the settings, so it was not used here.

- **The load.** The tables were read once and kept as one `qs2` file. Each run, in a new R process (`21a_run_bulk_load.R`), read them into memory and wrote them into a new file, created two secondary indexes (`PositionLink.gridpoint_id` and `SamplePosition.position_id`) and ran `ANALYZE`.
- **The variants.** A baseline (`journal_mode = OFF`, `synchronous = OFF`, `foreign_keys = OFF`, default temporary store, 1 GiB page cache, 4,096-byte pages, indexes after loading, rows in key order, one transaction) and 14 variants that each change one thing.
- **Runs.** Each variant ran twice, interleaved; times are medians with the range in brackets.
- **On the first baseline file:** the integrity checks, `ANALYZE` with a sampling limit, `VACUUM` in place and `VACUUM INTO`, checksums and compression. While `VACUUM` ran, the free space of drive C: (where SQLite writes its temporary files) and drive D: (the database) was polled every 0.1 s.

The machine is the one of question 2, and the source files were unchanged afterwards.

### Settings

| Variant | Load, indexes and `ANALYZE` (s) | Against the baseline | File (GB) | Peak memory (GB) |
| --- | ---: | ---: | ---: | ---: |
| baseline | 70.6 (70.2–71.0) | | 3.47 | 3.6 |
| SQLite defaults (`journal_mode = DELETE`, `synchronous = FULL`, 2 MB cache) | 76.8 (71.7–81.9) | +9 % | 3.47 | 3.1 |
| `journal_mode = DELETE`, `synchronous = NORMAL` | 72.9 (72.8–72.9) | +3 % | 3.47 | 3.6 |
| `journal_mode = WAL`, `synchronous = NORMAL` | 80.7 (80.4–81.0) | +14 % | 3.47 | 3.6 |
| `foreign_keys = ON` | 94.3 (93.3–95.3) | +34 % | 3.47 | 3.6 |
| `temp_store = MEMORY` | 86.6 (86.2–87.0) | +23 % | 3.47 | 7.6 |
| 2 MB page cache (the SQLite default) | 69.9 (69.3–70.6) | −1 % | 3.47 | 3.1 |
| 8 GiB page cache | 66.2 (64.4–68.1) | −6 % | 3.47 | 6.3 |
| 8,192-byte pages | 66.6 (64.5–68.6) | −6 % | 3.46 | 3.5 |
| 16,384-byte pages | 64.1 (62.9–65.3) | −9 % | 3.46 | 3.5 |
| 65,536-byte pages | 62.5 (62.1–62.9) | −11 % | 3.46 | 3.5 |
| indexes created before loading | 89.2 (87.1–91.3) | +26 % | 3.62 | 3.1 |
| `PositionLink` rows in random order | 260 (258–261) | ×3.7 | 3.40 | 5.5 |
| one transaction per chunk of 500 positions (747 commits) | 71.4 (71.0–71.7) | +1 % | 3.47 | 5.1 |
| the same with `journal_mode = WAL`, `synchronous = NORMAL` | 82.1 (81.2–83.0) | +16 % | 3.47 | 5.1 |

- **Journal and synchronous.** These barely matter for a load into a new file. Even SQLite's defaults cost only 9 %, because a new file gives the journal almost nothing to save. `OFF` is still the right choice for a work file that is rebuilt after any failure, but it is not where the time goes.
- **Foreign keys.** Checking them row by row during the load costs 24 s. One `foreign_key_check` of the finished file costs 5.8 s. Load with `foreign_keys = OFF` and check once.
- **Temporary store in memory.** It is slower (the index sorts take 39.5 s instead of 23.3 s) and needs 4 GB more memory. Keep the default.
- **Cache.** The cache size hardly matters: 2 MB and 1 GiB load at the same speed, and 8 GiB saves 6 %, mostly in `ANALYZE`.
- **Page size.** Larger pages build up to 11 % faster with the same file size. Their effect on the small reads of vaultkeepr was not measured, and all query plans of questions 3 and 4 used 4,096-byte pages, so the gain does not justify the change now.
- **Indexes after loading.** This is 26 % faster and gives a 4 % smaller file.
- **Key order.** Loading rows out of key order into a `WITHOUT ROWID` table is 3.7 times slower. The R engine sorts each table by its key before writing, and so must any 2.0.0 writer.
- **Transactions.** Committing per chunk costs nothing with the journal off, and 16 % with WAL and `synchronous = NORMAL`, which is the price of the resumable writes of question 5.

### Chunk size

The link step of question 5 was rerun on all 373,011 positions of v1.0.0 with five chunk sizes (`20_run_full_size_links.R`, `positions` target, reading the positions saved by the full-size run). Every chunk size gave the same 95,345,705 links and 1,560,757 gridpoints.

| Positions per chunk | Chunks | Link step (s) | Peak memory (GB) |
| ---: | ---: | ---: | ---: |
| 100 | 3,731 | 112.1 | 4.7 |
| 500 | 747 | 36.4 | 4.7 |
| 2,000 | 187 | 22.5 | 4.7 |
| 10,000 | 38 | 22.5 | 4.7 |
| 50,000 | 8 | 24.5 | 7.1 |

Up to 10,000 positions per chunk, the memory of the process is set by the links it keeps (1.53 GB) and the samples, not by the chunk. Chunks of 50,000 positions (about 12 M links each on average) add 2.4 GB. Chunks of 2,000 to 10,000 positions are fastest and leave the 64 GB machine almost untouched; in `{targets}`, that is 38 to 187 branches.

### `ANALYZE` and `VACUUM`

- **`ANALYZE`.** It takes 10.8 s on the 3.47 GB file. With `analysis_limit = 1000` it takes 1.25 s, but the full statistics are cheap enough to keep.
- **What `VACUUM` gains.** After a bulk load with the indexes created at the end, the free list is empty, but `VACUUM` still shrinks the file from 3.47 to 3.23 GB (7 %), because it rewrites the index b-trees full.
- **`VACUUM` in place** took 20.0 s. While it ran, the free space fell by 3.23 GB on drive C: (the temporary copy) and by 3.22 GB on drive D: (the rollback journal next to the database): twice the file size, on two drives.
- **`VACUUM INTO`** a new file took 10.1 s. It needed only the 3.23 GB of the new file on its own drive, nothing on C:, and left the source untouched. It copies the statistics tables, so `ANALYZE` can run first.

At the size of v1.0.0, an in-place `VACUUM` would need about 220 GB free across two drives, and at the measured rate (170 MB/s) about 11 minutes. That is extrapolated. With links stored per position, the 2.0.0 file is about 5 to 6 GB, so `VACUUM` stops being a planning problem. The rule that `VACUUM` never overlaps another heavy job still applies.

### Distributing the file

| File | Size | gzip `-6` | xz `-6`, 8 threads |
| --- | ---: | --- | --- |
| full-size position tables, after `VACUUM` | 3.23 GB | 797 MB (×4.1); 46 s; 8.5 s to decompress | 205 MB (×15.8); 47 s; 1.6 s to decompress |
| subset, v1 layout (question 4 `v1`) | 2.52 GB | | 169 MB (×14.9); 49 s |
| subset, links per position (question 4 `tuple_links`) | 128 MB | | 15 MB (×8.6); 4.8 s |

- **Checksums.** SHA-256 of the 3.23 GB file took 6.5 s (about 500 MB/s), and MD5 4.2 s.
- **Compression and layout.** The v1 layout compresses well because it repeats every link once per sample. The per-position layout has already removed that repetition, so it compresses less (×8.6 on the subset) but starts 20 times smaller.
- **A 2.0.0 file.** Extrapolated from these ratios and rates, a file of about 6 GB would compress to 0.4 to 0.7 GB with xz in about 1.5 minutes, and its SHA-256 would take about 12 s. No split is needed unless the repository limit is smaller than that.
- **The National Repository.** v1.0.0 is deposited there (the SQLite file and the flat files). Its size quota and how it versions a deposit are the early check of the publication task (VegVault issue 85), which has not reported yet, so this note cannot yet confirm the repository constraints.

## 7. Validation design

### What each check can see, and what it costs

- **Schema constraints** act on every write and stop the build at the first bad row. Primary keys and `UNIQUE` reject repeated keys, `NOT NULL` rejects missing values, and `CHECK` rejects values outside a stated range. They cannot see anything across tables beyond foreign keys, and SQLite applies foreign keys only when `foreign_keys = ON`.
- **`PRAGMA integrity_check`** reads the whole file once. It verifies the b-trees, that every index matches its table, and `UNIQUE`, `CHECK` and `NOT NULL` constraint errors. `quick_check` skips the index-against-table and `UNIQUE` checks. Neither looks at foreign keys.
- **`PRAGMA foreign_key_check`** verifies every declared foreign key once, against the parent's key.
- **The validation stage of #96 (P4)** reads the finished file read-only and checks what no constraint can express: semantic orphans, counts against v1.0.0, the plausibility of abiotic values, trait units against their contract, the link distance recomputed from coordinates, the version row against the build manifest, and release eligibility.

Measured costs:

| Check | Full-size position tables (3.47 GB, 107 M rows) | Subset, v1 layout (2.5 GB) | Subset, per-position layout (128 MB) | v1.0.0 (110 GB) |
| --- | ---: | ---: | ---: | ---: |
| `foreign_key_check` | 5.8 s | 2.5 s | 0.37 s | 325 s (question 1) |
| `quick_check` | 6.7 s | 3.6 s | 0.31 s | not run |
| `integrity_check` | 34.0 s | 23.5 s | 0.45 s | not run |

The full-size times come from the first baseline run of question 6, the subset times from question 4. With links stored per position, a full 2.0.0 file of about 6 GB needs roughly a minute for `integrity_check` and 10 to 20 s for `foreign_key_check` (extrapolated by size). Both can run on every release build, so there is no reason to fall back on `quick_check` except during development.

### Who checks what

| Rule | Enforced by | Checked again by | Not checked by |
| --- | --- | --- | --- |
| row ids unique; composite keys of the junction and value tables (except `SampleTaxa`) | schema: primary keys (`WITHOUT ROWID`, question 4) | `integrity_check` | P4 (it only confirms that the key exists in the schema) |
| sample and dataset names unique and present; one row per position | schema: `UNIQUE NOT NULL` | `integrity_check` | P4 |
| coordinates within −180 to 180 and −90 to 90; links within 50 km and 5,000 years; `mandatory` 0 or 1 | schema: `CHECK` | `integrity_check` | P4 row checks (the age bound of every link need not be queried again) |
| link distance correct, not only within range | — | P4: geodesic distance recomputed for a stratified sample, including dateline and polar positions (question 5 shows how) | schema (a `CHECK` cannot recompute a distance) |
| every child row has its parent | schema declares the foreign keys; the load runs with `foreign_keys = OFF` (question 6) | P4: one `foreign_key_check` of the release file, blocking | the assembly stage |
| file and index structure | — | P4: one `integrity_check` of the release file, blocking | the assembly stage |
| `SampleTaxa` (sample, taxon) unique | not yet possible: v1.0.0 repeats 189,639 pairs | P4: flag until the vegetation producers resolve them; then a primary key in the schema | |
| taxon names and trait names unique | not decided: their duplicates were not measured | P4 first; a `UNIQUE` constraint once a build shows none | |
| semantic orphans (for example positions without samples, gridpoints without links or values, datasets without samples) | — | P4 | |
| ages plausible | — | P4: flag only; no document fixes a range | schema |
| abiotic values plausible (the `bio4` and `bio12` defects of VegVault issue 78) | — | P4, with thresholds from the producer contracts of #93 | schema (thresholds change with producer versions and are shares, not row rules) |
| trait value has a unit-conversion rule | schema: `NOT NULL` foreign key to the rule (the #76 schema on `OndrejMottl/issue76`) | `foreign_key_check` | |
| the rule's unit matches the domain's canonical unit | — | P4 (cross-table) | schema |
| impossible coordinates in producer artefacts | the import, before linking (one TRY position got 176 links through the dateline wrap, question 5); the `CHECK` stops what slips through | P4 counts what the import dropped | |
| counts against v1.0.0, version row against the build manifest, release eligibility | — | P4 | |

Three rules keep the work single:

- **Constraints are checked once.** P4 does not query the uniqueness or ranges that the schema enforces; it confirms from `sqlite_schema` that the constraint is there, and `integrity_check` verifies it.
- **One place for whole-file checks.** The assembly stage writes, runs `ANALYZE` and finishes with `VACUUM INTO`; P4 runs `foreign_key_check` and `integrity_check` once on the release file.
- **P4 checks the semantics.** Its checks carry thresholds from `config.yml` or the contracts, and anything legitimately different from v1.0.0 (the new link rule, new source versions, the TRY decision) is flagged for review rather than failed.

### Which constraints belong in the schema

Into the schema go the rules that are true by definition and do not change with a producer release:

- keys;
- presence of key and foreign-key columns;
- the documented ranges: coordinates and the link rule;
- the foreign key from a trait value to its conversion rule.

They cost nothing measurable at build time (question 4), and they turn a silent defect into a failed build.

Into P4 go the rest:

- rules that need a threshold or judgement;
- rules that span tables beyond a foreign key;
- rules the current content does not yet satisfy (`SampleTaxa`, and the 514 TRY datasets with coordinates out of range until the import handles them).

Unit names stay out of `CHECK` constraints: the unit contract belongs to lane L6 and is checked by P4 against that contract.

## Recommendations

One recommendation per question, each with one tag.

1. **What is in v1.0.0: fix the content gaps upstream** (2.0.0, no vaultkeepr change). The gaps of section 1 go to the producer lanes before the 2.0.0 import:
   - the 8,883 TRY samples with impossible coordinates (514 datasets out of range, 4,410 with a missing coordinate): reject or repair them on import;
   - the 189,639 repeated (sample, taxon) pairs of the BIEN and sPlotOpen plots: decide how to merge them;
   - the 238,777 BIEN trait samples without a value: drop them, or document why they stay.
2. **Where the time goes: replace the v1 gridpoint stage** (2.0.0, no vaultkeepr change). Replace it rather than tune it: the 2.0.0 link step of question 5 removes every large v1 cost at once (`ANALYZE` after every batch, the whole-globe coarse filter, the whole-table reads, one distance call per candidate pair).
3. **How vaultkeepr uses the database: fix five query shapes** (2.0.0 with vaultkeepr change). They matter more than any schema change:
   - the mandatory-reference check of `extract_data()`, 70 % of the query time;
   - the `CASE` box filter, which cannot use the coordinate index and lets unselected dataset types through;
   - the correlated `EXISTS` of `get_age_uncertainty()`, about 70 times slower than `IN` on the subset;
   - the classification of taxa before the box filter;
   - the version reader, which takes the last row of an unordered query.
4. **Schema: adopt the measured schema package** (2.0.0, no vaultkeepr change).
   - **Adopt:**
     - links stored once per position, with the view `AbioticDataReference` that keeps the v1 rows for vaultkeepr;
     - `WITHOUT ROWID` composite primary keys on the junction and value tables except `SampleTaxa`;
     - the index set of question 4 (drop the 12 unused primary-key duplicates, the 15 unused indexes and the prefix duplicate; keep `idx_samples_sample_id`, `idx_datasets_dataset_id`, the uncertainty key and the coordinate index); revised at gate G2 to drop only redundant indexes (decision 3 below);
     - `UNIQUE NOT NULL` sample and dataset names, and `CHECK` constraints on coordinates and the link rule;
     - the version hook (build columns and `BuildProducers`).
   - **Keep:** km and years as integers and ages as `REAL`.
   - **Effect:** the projected file falls from 110 GB to about 5.3 GB.
   - **Later:** dedicated gridpoint tables.
5. **Build engine: R in memory** (2.0.0, no vaultkeepr change). Compute the links in dplyr, with chunks of 2,000 to 10,000 positions as `{targets}` branches, and write the file in one bulk load. Measured at full size, the link step takes 22.5 s and writing the position tables 35 s. Do not adopt DuckDB.
6. **Bulk-load practice: the section 6 settings** (2.0.0, no vaultkeepr change).
   - **Load:** into a new work file, with the journal and synchronous off, foreign keys off, the default temporary store and page size, and a 1 GiB cache. Write parents first, each table in key order, with indexes after loading.
   - **Finish:** a full `ANALYZE`, then `VACUUM INTO` the release file.
   - **Publish:** the file with an xz copy and SHA-256 checksums of both, once the National Repository quota is known (VegVault issue 85).
7. **Validation: the section 7 split** (2.0.0, no vaultkeepr change). The schema enforces keys and documented ranges. P4 runs `integrity_check` and `foreign_key_check` once on the release file and the semantic checks; it does not repeat row checks that the schema covers.

## Decisions for gate G2

**Gate G2 passed on 2026-11-20.** Ondřej decided all 11 items: decision 3 in a revised form, the other ten as recommended. Each decision below ends with what was decided.

Each decision gives the recommended option, then what it means for the schema task (#88), the linkage task (#89), the assembly task (#90), the validation task (#96) and the vaultkeepr lane (L7, OndrejMottl/vaultkeepr#52).

1. **Links per position.** Recommended: yes, with the compatibility view `AbioticDataReference`. The alternative, keeping one row per sample and gridpoint, projects to 47 GB even with `WITHOUT ROWID`.
   - **#88:** add `Positions`, `SamplePosition`, `PositionLink` and the view.
   - **#89:** computes links per position under the 2.0.0 rule and rejects impossible coordinates first.
   - **#90:** loads the tables in key order.
   - **#96:** compares the v1 links through the view and checks the distances on a sample.
   - **L7:** no change needed.
   - **Decided by Ondřej on 2026-11-20: as recommended.** The export stage (`R/Analyses/05_Export`, pipeline lane) writes the three position tables and not the view `AbioticDataReference`: `DBI::dbListTables()` also lists views, so the export would otherwise write the view as a CSV of about 2 billion rows. The export documentation says how to join the position tables to the samples.
2. **Composite primary keys.** Recommended: `WITHOUT ROWID` with composite keys on the 13 junction and value tables, with `SampleTaxa` excluded until its duplicates are resolved.
   - **#88:** writes the DDL.
   - **#90:** loads in key order.
   - **#96:** drops the uniqueness checks the keys cover and flags `SampleTaxa`.
   - **Vegetation lane:** resolves the duplicates.
   - **L7:** none.
   - **Decided by Ondřej on 2026-11-20: as recommended.** For the 189,639 repeated (sample, taxon) pairs, the vegetation lane finds out whether the sources or the import's matching of taxon names repeat them, and proposes a merge rule per source for Ondřej's approval. If they are not resolved before the build, 2.0.0 keeps `SampleTaxa` as a rowid table and #96 flags the pairs.
   - **Resolved on 2026-11-23.** The vegetation producers merge repeated taxa into one record per taxon, and the assembly's source preparers, run on the development files, give no repeated pair (sPlotOpen 1,508,470 rows, BIEN 524,439, FOSSILPOL 1,365,322). Ondřej decided that `SampleTaxa` gets the primary key `(sample_id, taxon_id)` as a `WITHOUT ROWID` table, and `idx_sampletaxa_sample_id_taxon_id`, which the key makes redundant, is dropped (#90).
3. **Index set.** Recommended: as in question 4. Drop 28 indexes and keep the two primary-key duplicates that vaultkeepr's reference check uses. Add no index on `PositionLink.gridpoint_id`.
   - **#88:** writes the index list.
   - **#90:** creates the indexes after loading.
   - **L7:** once the reference check changes, the two kept duplicates can go.
   - **Decided by Ondřej on 2026-11-20, in a revised form.** "Unused" in question 3 means unused by the 11 workloads of vaultkeepr 0.1.0. It does not cover direct SQL users of the file, the two exported functions that were not run, or the query shapes of decision 10, which change the indexes vaultkeepr needs. Once links are stored per position, the indexes that are unused but not redundant take under 1 GB at v1.0.0 size, so they stay. The rule: drop an index only when it is redundant by definition, and keep every other one.
   - **Drop 29 of the 59 indexes of `Data/SQL/make_tables.sql`:**
     - the 12 unique indexes that duplicate an `INTEGER PRIMARY KEY` and appear in no plan: `idx_version_control_id`, `idx_authors_author_id`, `idx_datasettypeid_dataset_type_id`, `idx_datasetsourcetypeid_data_source_type_id`, `idx_datasetsourcesid_data_source_id`, `idx_samplingmethodid_sampling_method_id`, `idx_samplesizeid_sample_size_id`, `idx_taxa_taxon_id`, `idx_traitsdomain_trait_domain_id`, `idx_traits_trait_id`, `idx_abioticvariable_abiotic_variable_id` and `idx_references_reference_id`;
     - the prefix duplicate `idx_sampletaxa_sample_id`, the first column of `idx_sampletaxa_sample_id_taxon_id`;
     - the two indexes of the v1 link table, which becomes the view `AbioticDataReference` (decision 1): `idx_abioticdatareference_sample_id` and `idx_abioticdatareference_sample_ref_id`;
     - the 14 indexes that a new primary key makes redundant (decision 2, as in the `without_rowid` prototype): `idx_datasetreferences_dataset_id`, `idx_datasetsourcetypereference_data_source_type_id`, `idx_datasetsourcesreference_data_source_id`, `idx_samplingmethodreference_sampling_method_id`, `idx_samplereference_sample_id`, `idx_datasetsample_dataset_id`, `idx_sampleuncertainty_sample_id`, `idx_taxonreference_taxon_id`, `idx_traitsreference_trait_id`, `idx_abioticdata_sample_id`, `idx_abioticvariablereference_abiotic_variable_id`, `idx_traitsvalue_dataset_id` and `idx_traitsvalue_dataset_id_sample_id_taxon_id` (both lead with the first columns of the key `dataset_id, sample_id, trait_id, taxon_id`), and `idx_taxonclassification_taxon_id` (`taxon_id` becomes the primary key of `TaxonClassification`).
   - **Keep the other 30**, among them:
     - the two primary-key duplicates of the reference check, `idx_samples_sample_id` and `idx_datasets_dataset_id`;
     - 11 indexes that question 3 found unused but that serve lookups from the other direction: `idx_abioticdata_abiotic_variable_id`, `idx_traitsvalue_trait_id`, `idx_traitsvalue_sample_id`, `idx_samples_sample_size_id`, `idx_traits_trait_domain_id`, the three rank indexes of `TaxonClassification` (`taxon_species`, `taxon_genus`, `taxon_family`) and the `reference_id` indexes of `TaxonReference`, `TraitsReference` and `SamplingMethodReference`;
     - the three indexes added with the trait unit contract after question 3, which were not measured: `idx_traitsdomain_trait_domain_name`, `idx_traitsvalue_trait_unit_conversion_id` and `idx_traitsvalue_trait_derivation_id`.
   - **Still no index on `PositionLink.gridpoint_id`.** vaultkeepr never reads links by gridpoint, and the index would cover all 95 M position links (its size was not measured). "Which positions use this gridpoint" is the one reverse lookup left unserved.
   - **Follow-up:** after the vaultkeepr lane changes its query shapes (decision 10), rerun `12_profile_vaultkeepr_queries.R` on the 2.0.0 rehearsal database and revisit the index set. Adding an index later is cheap.
4. **Natural keys and `CHECK` constraints.** Recommended: `UNIQUE NOT NULL` on sample and dataset names, and `CHECK` on coordinates, link km and years, and `References.mandatory`.
   - **#88:** writes the constraints.
   - **#89:** handles the 514 TRY datasets with coordinates out of range before linking.
   - **#96:** drops the row checks these constraints cover.
   - **L7:** none.
   - **Decided by Ondřej on 2026-11-20: as recommended.** The trait lane sets coordinates outside −180 to 180 and −90 to 90 to missing in its export, so the trait values stay, unlinked, like the TRY and BIEN datasets that already have no coordinate; the `try_traits` and `bien_traits` contracts already reject coordinates out of range. The trait lane also drops the 238,777 BIEN trait samples without a value. The import (#89) and the `CHECK` constraint stop anything that slips through.
5. **Distance and age types.** Recommended: keep km as an integer rounded down (as in v1), years as an integer, and ages as `REAL`. The alternative, integer metres, keeps the distance to the metre for 0.17 GB more; 3.3 % of the links lie between 49 and 50 km and are stored as 49.
   - **#88, #89 and L7:** none with the recommended option. Metres would be a vaultkeepr change, because the column and unit change.
   - **Decided by Ondřej on 2026-11-20: as recommended.**
6. **Gridpoints.** Recommended: keep them as `Datasets` and `Samples` rows in 2.0.0, and decide dedicated tables later. They would save 4 % and break vaultkeepr 0.1.0, partly without any message.
   - **#88 and L7:** none.
   - **Decided by Ondřej on 2026-11-20: as recommended.**
7. **Version hook.** Recommended: build columns on `version_control` (`build_profile`, `git_commit`, `manifest_sha256`), a `BuildProducers` table with one row per producer pin, and version rows written in the order of `config.yml`.
   - **#88:** writes the DDL.
   - **C3 (VegVault issue 84):** fills the 2.0.0 row.
   - **#96:** compares it with the build manifest.
   - **L7:** orders the version reader by `id`.
   - **Decided by Ondřej on 2026-11-20: as recommended.**
   - **Changed on 2026-11-23.** Ondřej decided that the pin manifest records no commit of a producer tag, because it already records the size and SHA-256 of every file (#95). `BuildProducers.commit_sha` would therefore always be empty, and he decided to drop it: `BuildProducers` holds `version_id`, `producer` and `tag` (#90).
8. **Build engine and load settings.** Recommended: R in memory with `{targets}` branches of 2,000 to 10,000 positions, one bulk load with the settings of section 6, and `VACUUM INTO` the release file.
   - **#89:** implements the link step.
   - **#90:** implements the assembly.
   - **No new dependency:** DuckDB is not adopted.
   - **Decided by Ondřej on 2026-11-20: as recommended.**
9. **Validation split.** Recommended: section 7.
   - **#96:** implements its share.
   - **#88:** provides the constraints P4 relies on.
   - **Decided by Ondřej on 2026-11-20: as recommended.**
10. **vaultkeepr query shapes.** Recommended: the five changes of recommendation 3, in vaultkeepr's 2.0.0 release.
    - **L7:** implements them.
    - **The schema:** does not depend on them, except for the two kept primary-key duplicates.
    - **Decided by Ondřej on 2026-11-20: as recommended.** All five go into vaultkeepr 0.1.1, the release that reads 2.0.0. The change of the box filter also corrects a wrong result: the current filter keeps the datasets of every unselected type, wherever they lie.
11. **Distribution.** Recommended: one SQLite file plus an xz copy, each with a SHA-256 checksum.
    - **The build task (VegVault issue 83):** records the checksums.
    - **The publication task (VegVault issue 85):** confirms the National Repository quota and versioning before the deposit.
    - **Decided by Ondřej on 2026-11-20: as recommended**, subject to the National Repository check of VegVault issue 85. If that check rules out this form, the distribution comes back for a decision.
