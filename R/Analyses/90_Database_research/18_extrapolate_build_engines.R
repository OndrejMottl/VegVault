#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Extrapolate the build-engine benchmark to v1.0.0
#                 - from saved results only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Extrapolate the step times and the R memory of the build-engine
#   benchmark (17_benchmark_build_engines.R, on the regional subset) to the
#   content of v1.0.0. No database is opened. Each step time (median of the
#   repetitions) is multiplied by the ratio of the count that drives it at
#   v1.0.0 size to the same count on the subset:
#   - reading the samples: samples with coordinates and age;
#   - positions and writing them: positions and mapped samples;
#   - links and the linked gridpoints (found from the links): links;
#   - copying the other tables, indexes: copied rows;
#   - writing everything and `ANALYZE`: all rows written;
#   - reading the global inputs (DuckDB): no change, the subset runs read
#     the global cells already.
#   Every count is measured: on the subset from the benchmark itself, on
#   v1.0.0 from 01_inspect_v1_metadata.R (row counts) and
#   15_check_v1_schema_candidates.R (positions, mapped samples, position
#   links and gridpoint rows). The v1.0.0 links follow the v1 rule; the
#   2.0.0 rule adds links at high latitude and across the dateline (2.8 %
#   more on the subset), so the link terms are lower bounds. The gridpoint
#   values are counted as all v1.0.0 abiotic values, although the benchmark
#   wrote only bio1 at age 0.
# The R memory is extrapolated from the measured bytes per link and per
#   copied row of r_memory.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/18_extrapolate_build_engines.R
#     <run folder of script 17> <run folder of script 15>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 2L,
  base::all(stringr::str_detect(vec_args, "^run_[0-9_]+$")),
  msg = "Give the run folders of scripts 17 and 15."
)

path_research <-
  here::here("Data", "Temp", "Database_research")

path_engines <-
  base::file.path(path_research, "Engines", purrr::chuck(vec_args, 1L))

path_v1_checks <-
  base::file.path(
    path_research, "V1_schema_checks", purrr::chuck(vec_args, 2L)
  )

assertthat::assert_that(
  base::dir.exists(path_engines),
  base::dir.exists(path_v1_checks),
  msg = "A run folder does not exist."
)

data_steps <-
  readr::read_csv(
    file = base::file.path(path_engines, "steps.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_memory <-
  readr::read_csv(
    file = base::file.path(path_engines, "memory.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_fingerprints <-
  readr::read_csv(
    file = base::file.path(path_engines, "fingerprints.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_v1_rows <-
  readr::read_csv(
    file = base::file.path(path_research, "V1_metadata", "rowid_bounds.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_position_links <-
  readr::read_csv(
    file = base::file.path(path_v1_checks, "position_link_counts.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_position_sizes <-
  readr::read_csv(
    file = base::file.path(path_v1_checks, "position_sizes.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_gridpoint_columns <-
  readr::read_csv(
    file = base::file.path(path_v1_checks, "gridpoint_columns.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_gridpoint_references <-
  readr::read_csv(
    file = base::file.path(path_v1_checks, "gridpoint_references.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )


#----------------------------------------------------------#
# 1. Counts on the subset and on v1.0.0 -----
#----------------------------------------------------------#

# Subset: the rows of the reference output
data_subset_rows <-
  data_fingerprints |>
  dplyr::filter(label == "r_memory_rep1") |>
  dplyr::select(table_name, n_rows)

vec_new_tables <-
  c("Positions", "SamplePosition", "PositionLink", "Gridpoints",
    "GridpointValues")

n_subset_copy_rows <-
  data_subset_rows |>
  dplyr::filter(!table_name %in% vec_new_tables) |>
  dplyr::pull(n_rows) |>
  base::sum()

# v1.0.0: the copied tables without their gridpoint rows
n_v1_gridpoint_samples <-
  data_gridpoint_columns |>
  dplyr::pull(n_samples) |>
  base::sum()

n_v1_gridpoint_datasets <-
  data_gridpoint_columns |>
  dplyr::pull(n_datasets) |>
  base::sum()

data_v1_copy_rows <-
  data_v1_rows |>
  dplyr::filter(
    table_name %in% (data_subset_rows |> dplyr::pull(table_name))
  ) |>
  dplyr::select(table_name, n_rows = max_rowid) |>
  dplyr::left_join(
    tibble::tribble(
      ~table_name, ~n_gridpoint_rows,
      "Datasets", n_v1_gridpoint_datasets,
      "Samples", n_v1_gridpoint_samples,
      "DatasetSample", n_v1_gridpoint_samples,
      "SampleReference", data_gridpoint_references |>
        dplyr::filter(table_name == "SampleReference") |>
        dplyr::pull(n_gridpoint_rows),
      "DatasetReferences", data_gridpoint_references |>
        dplyr::filter(table_name == "DatasetReferences") |>
        dplyr::pull(n_gridpoint_rows)
    ),
    by = "table_name"
  ) |>
  dplyr::mutate(
    n_copied = n_rows - dplyr::coalesce(n_gridpoint_rows, 0)
  )

n_v1_copy_rows <-
  data_v1_copy_rows |>
  dplyr::pull(n_copied) |>
  base::sum()

n_v1_positions <-
  data_position_sizes |>
  dplyr::pull(n_positions) |>
  base::sum()

n_v1_mapped_samples <-
  data_position_sizes |>
  dplyr::summarise(n = base::sum(n_samples * n_positions)) |>
  dplyr::pull(n)

n_v1_links <-
  data_position_links |>
  dplyr::summarise(n = base::sum(n_links * n_positions)) |>
  dplyr::pull(n)

n_v1_values <-
  data_v1_rows |>
  dplyr::filter(table_name == "AbioticData") |>
  dplyr::pull(max_rowid)

data_counts <-
  tibble::tribble(
    ~unit, ~n_subset, ~n_v1,
    "samples",
    data_subset_rows |>
      dplyr::filter(table_name == "SamplePosition") |>
      dplyr::pull(n_rows),
    n_v1_mapped_samples,
    "positions",
    data_subset_rows |>
      dplyr::filter(table_name %in% c("Positions", "SamplePosition")) |>
      dplyr::pull(n_rows) |>
      base::sum(),
    n_v1_positions + n_v1_mapped_samples,
    "links",
    data_subset_rows |>
      dplyr::filter(table_name == "PositionLink") |>
      dplyr::pull(n_rows),
    n_v1_links,
    "copied_rows",
    n_subset_copy_rows,
    n_v1_copy_rows,
    "late_rows",
    n_subset_copy_rows +
      data_subset_rows |>
      dplyr::filter(table_name %in% c("Gridpoints", "GridpointValues")) |>
      dplyr::pull(n_rows) |>
      base::sum(),
    n_v1_copy_rows + n_v1_gridpoint_samples + n_v1_values,
    "all_rows",
    data_subset_rows |>
      dplyr::pull(n_rows) |>
      base::sum(),
    n_v1_copy_rows + n_v1_positions + n_v1_mapped_samples + n_v1_links +
      n_v1_gridpoint_samples + n_v1_values,
    "fixed",
    1,
    1
  ) |>
  dplyr::mutate(ratio = n_v1 / n_subset)

readr::write_csv(
  x = data_counts,
  file = base::file.path(path_engines, "extrapolation_counts.csv")
)


#----------------------------------------------------------#
# 2. Step times -----
#----------------------------------------------------------#

data_step_units <-
  tibble::tribble(
    ~step, ~unit,
    "read_inputs", "fixed",
    "read_samples", "samples",
    "positions", "positions",
    "write_positions", "positions",
    "links", "links",
    "gridpoints", "links",
    "read_copies", "copied_rows",
    "write_late_steps", "late_rows",
    "write", "all_rows",
    "indexes", "copied_rows",
    "analyze", "all_rows"
  )

data_extrapolation <-
  data_steps |>
  dplyr::filter(
    stringr::str_detect(label, "_rep[0-9]+$"),
    !base::is.na(seconds)
  ) |>
  dplyr::summarise(
    seconds_subset = stats::median(seconds),
    seconds_subset_min = base::min(seconds),
    seconds_subset_max = base::max(seconds),
    .by = c(engine, step)
  ) |>
  dplyr::left_join(data_step_units, by = "step") |>
  dplyr::left_join(
    data_counts |> dplyr::select(unit, ratio),
    by = "unit"
  ) |>
  dplyr::mutate(seconds_v1 = seconds_subset * ratio)

assertthat::assert_that(
  !base::anyNA(data_extrapolation |> dplyr::pull(seconds_v1)),
  msg = "A step has no unit to extrapolate by."
)

readr::write_csv(
  x = data_extrapolation,
  file = base::file.path(path_engines, "extrapolation_steps.csv")
)


#----------------------------------------------------------#
# 3. Totals and memory -----
#----------------------------------------------------------#

# Bytes per link and per copied row held in R by r_memory
data_bytes <-
  data_steps |>
  dplyr::filter(
    engine == "r_memory",
    step %in% c("bytes_links_in_r", "bytes_copies_in_r")
  ) |>
  dplyr::summarise(bytes = stats::median(n_rows), .by = step)

value_bytes_per_link <-
  data_bytes |>
  dplyr::filter(step == "bytes_links_in_r") |>
  dplyr::pull(bytes) /
  (data_counts |> dplyr::filter(unit == "links") |> dplyr::pull(n_subset))

value_bytes_per_copied_row <-
  data_bytes |>
  dplyr::filter(step == "bytes_copies_in_r") |>
  dplyr::pull(bytes) /
  n_subset_copy_rows

data_engine_totals <-
  data_extrapolation |>
  dplyr::summarise(
    seconds_subset = base::sum(seconds_subset),
    seconds_v1 = base::sum(seconds_v1),
    .by = engine
  ) |>
  dplyr::left_join(
    data_memory |>
      dplyr::filter(stringr::str_detect(label, "_rep[0-9]+$")) |>
      dplyr::summarise(
        peak_wset_mb_subset = stats::median(peak_wset_mb),
        file_mb_subset = stats::median(file_mb),
        .by = engine
      ),
    by = "engine"
  ) |>
  dplyr::mutate(
    bytes_per_link_in_r = value_bytes_per_link,
    bytes_per_copied_row_in_r = value_bytes_per_copied_row,
    # Data r_memory holds before writing, at v1.0.0 size
    gb_data_in_r_v1 = dplyr::if_else(
      engine == "r_memory",
      (value_bytes_per_link * n_v1_links +
        value_bytes_per_copied_row * n_v1_copy_rows) / 1e9,
      NA_real_
    )
  )

readr::write_csv(
  x = data_engine_totals,
  file = base::file.path(path_engines, "extrapolation_totals.csv")
)

cli::cli_inform(
  c(
    "v" = "Extrapolated the build engines to v1.0.0.",
    "i" = "Results in {.path {path_engines}}."
  )
)
