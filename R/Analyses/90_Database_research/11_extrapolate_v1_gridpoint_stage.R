#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Extrapolate the v1 gridpoint stage to full size
#          - from the profiling results, no new timing
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Combine the measured unit costs of the profiling runs with the measured
#   v1.0.0 counts into a full-size estimate of the v1 gridpoint stage
#   (R/02_Main_analyses/06_Create_gridpoints.R), one term per cost. Every
#   term is an extrapolation and a lower bound: the unit costs were
#   measured at subset size, where the tables and indexes fit in memory,
#   and v1.0.0 does not. Inputs:
#   - the last complete run of 08_profile_v1_gridpoints.R for the full
#     subset box (per-batch pairs, links, and step times)
#   - the last run of 09_profile_v1_global_batches.R (coarse filter and
#     import filter against the whole-globe candidates)
#   - the last run of 10_benchmark_link_writes.R (writes, `ANALYZE`, and
#     whole-table reads)
#   - the v1.0.0 counts of 06_scan_v1_full.R
#   - the pre-gridpoint database of the full box (read-only), to rebuild
#     the v1 batches and tell age-0 positions from the others
# The method of each term is written next to it in the output table.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration
source(
  here::here("R/00_Config_file.R")
)

name_box <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  ) |>
  purrr::chuck("subset", "box_name")

path_research <-
  here::here("Data", "Temp", "Database_research")

path_profiling <-
  base::file.path(path_research, "Profiling")

path_scans <-
  base::file.path(path_research, "V1_full_scans")

path_output <-
  base::file.path(path_research, "V1_extrapolation")

base::dir.create(
  path = path_output,
  recursive = TRUE,
  showWarnings = FALSE
)

# The last run folder of a profiling script that finished (has run_info)
vec_run_box <-
  base::list.files(
    path = base::file.path(path_profiling, name_box),
    pattern = "^run_",
    full.names = TRUE
  ) |>
  purrr::keep(
    .p = ~ base::file.exists(base::file.path(.x, "run_info.csv"))
  )

path_run_box <-
  vec_run_box |>
  utils::tail(n = 1L)

path_run_global <-
  base::list.files(
    path = base::file.path(path_profiling, "global"),
    pattern = "^run_",
    full.names = TRUE
  ) |>
  utils::tail(n = 1L)

path_run_writes <-
  base::list.files(
    path = base::file.path(path_profiling, "writes"),
    pattern = "^run_",
    full.names = TRUE
  ) |>
  utils::tail(n = 1L)

path_template <-
  base::file.path(path_profiling, name_box, "pre_gridpoints.sqlite")

# v1 processes positions in batches of this size
n_positions_per_batch <- 500L

# The steps of get_gridpoints_link() timed separately, by label start
vec_step_labels <-
  c(
    coarse = "vec_gridpoits_coarse_filtering <-",
    fine = "data_vegetation_grid_data <-",
    distance = "data_vegetation_distance <-"
  )

assertthat::assert_that(
  base::length(path_run_box) == 1L,
  base::length(path_run_global) == 1L,
  base::length(path_run_writes) == 1L,
  msg = "A profiling run is missing; run scripts 08, 09 and 10 first."
)


#----------------------------------------------------------#
# 1. v1.0.0 counts -----
#----------------------------------------------------------#

data_v1_tuples_per_source <-
  readr::read_csv(
    file = base::file.path(path_scans, "tuples_per_source.csv"),
    show_col_types = FALSE
  )

n_positions_v1 <-
  readr::read_csv(
    file = base::file.path(path_scans, "tuples_all_sources.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::pull(n_tuples)

# Only fossil pollen (source 3) has ages other than 0
n_positions_v1_other <-
  data_v1_tuples_per_source |>
  dplyr::filter(data_source_type_id == 3) |>
  dplyr::pull(n_tuples)

n_positions_v1_age0 <-
  n_positions_v1 - n_positions_v1_other

n_batches_v1 <-
  base::ceiling(n_positions_v1 / n_positions_per_batch)

n_links_v1 <-
  readr::read_csv(
    file = base::file.path(path_scans, "link_distance_types.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::pull(n_links) |>
  base::sum()

data_v1_samples <-
  readr::read_csv(
    file = base::file.path(path_scans, "sample_composition.csv"),
    show_col_types = FALSE
  )

n_samples_v1_before <-
  data_v1_samples |>
  dplyr::filter(dataset_type_id != 4) |>
  dplyr::pull(n_samples) |>
  base::sum()

n_samples_v1_after <-
  data_v1_samples |>
  dplyr::pull(n_samples) |>
  base::sum()

n_datasets_v1 <-
  readr::read_csv(
    file = base::file.path(path_scans, "dataset_composition.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::pull(n_datasets) |>
  base::sum()

# Samples and DatasetSample grow from the non-gridpoint samples to all
#   samples during the stage; their mean size is used
n_samples_v1_mean <-
  (n_samples_v1_before + n_samples_v1_after) / 2


#----------------------------------------------------------#
# 2. Per-batch results of the full-box run -----
#----------------------------------------------------------#

# Each traced event: function, kind, time, row counts in the frame
data_events_box <-
  readr::read_csv(
    file = base::file.path(path_run_box, "events.csv"),
    col_names = c("fn_name", "kind", "epoch", "extras"),
    col_types = "ccdc"
  ) |>
  dplyr::mutate(
    call_id = 1L + base::cumsum(dplyr::lag(kind == "exit", default = FALSE)),
    .by = fn_name
  ) |>
  dplyr::mutate(
    step_order = base::cumsum(kind == "step"),
    seconds = dplyr::lead(epoch) - epoch,
    .by = c(fn_name, call_id)
  )

# Step numbers of the separately timed steps
vec_step_order <-
  readr::read_csv(
    file = base::file.path(path_run_box, "trace_steps.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::filter(fn_name == "get_gridpoints_link") |>
  dplyr::mutate(
    step_name = purrr::map_chr(
      .x = step_label,
      .f = ~ base::names(vec_step_labels)[
        stringr::str_starts(.x, stringr::fixed(vec_step_labels))
      ][1]
    )
  ) |>
  tidyr::drop_na(step_name) |>
  dplyr::select(step_name, step_order) |>
  tibble::deframe()

assertthat::assert_that(
  base::setequal(base::names(vec_step_order), base::names(vec_step_labels)),
  msg = "A timed step of get_gridpoints_link() was not found."
)

# Candidate pairs (rows of the distance table) and step times per batch
data_box_batches <-
  data_events_box |>
  dplyr::filter(fn_name == "get_gridpoints_link") |>
  dplyr::summarise(
    n_positions = dplyr::last(extras) |>
      stringr::str_extract("(?<=(^|;)data_source=)[0-9]+") |>
      base::as.numeric(),
    n_pairs = dplyr::last(extras) |>
      stringr::str_extract("(?<=;data_vegetation_distance=)[0-9]+") |>
      base::as.numeric(),
    seconds_fine = base::sum(
      seconds[
        kind == "step" &
          step_order == purrr::chuck(vec_step_order, "fine")
      ]
    ),
    seconds_distance = base::sum(
      seconds[
        kind == "step" &
          step_order == purrr::chuck(vec_step_order, "distance")
      ]
    ),
    .by = call_id
  ) |>
  dplyr::rename(batch = call_id)

# The v1 batches of the full box, rebuilt as in add_gridpoints_with_links()
con_template <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_template,
    flags = RSQLite::SQLITE_RO
  )

data_box_positions <-
  tryCatch(
    expr = {
      dplyr::tbl(con_template, "Datasets") |>
        dplyr::filter(dataset_type_id != 4) |>
        dplyr::inner_join(
          dplyr::tbl(con_template, "DatasetSample"),
          by = dplyr::join_by("dataset_id")
        ) |>
        dplyr::left_join(
          dplyr::tbl(con_template, "Samples") |>
            dplyr::select("sample_id", "sample_name", "age"),
          by = dplyr::join_by("sample_id")
        ) |>
        dplyr::select(
          "dataset_name", "sample_name", "coord_long", "coord_lat", "age"
        ) |>
        dplyr::distinct() |>
        dplyr::collect()
    },
    finally = DBI::dbDisconnect(con_template)
  ) |>
  dplyr::distinct(
    dataset_name, sample_name,
    coord_long, coord_lat,
    age
  ) |>
  dplyr::group_by(coord_long, coord_lat, age) |>
  tidyr::nest(data = -c("coord_long", "coord_lat", "age")) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    batch = 1L + (dplyr::row_number() - 1L) %/% n_positions_per_batch
  ) |>
  dplyr::summarise(
    n_positions_rebuilt = dplyr::n(),
    n_age0 = base::sum(age == 0),
    n_other = base::sum(age != 0),
    .by = batch
  )

data_box_batches_classed <-
  data_box_batches |>
  dplyr::left_join(
    data_box_positions,
    by = dplyr::join_by(batch),
    relationship = "one-to-one"
  )

assertthat::assert_that(
  base::all(
    data_box_batches_classed |>
      dplyr::pull(n_positions) ==
      data_box_batches_classed |>
        dplyr::pull(n_positions_rebuilt)
  ),
  msg = "The rebuilt batches do not match the traced batches."
)

# Candidate pairs per position, by age class (least squares, no intercept)
mod_pairs <-
  stats::lm(
    formula = n_pairs ~ 0 + n_age0 + n_other,
    data = data_box_batches_classed
  )

vec_pairs_per_position <-
  stats::coef(mod_pairs)

seconds_per_pair <-
  base::sum(data_box_batches |> dplyr::pull(seconds_distance)) /
  base::sum(data_box_batches |> dplyr::pull(n_pairs))

seconds_fine_per_position <-
  base::sum(data_box_batches |> dplyr::pull(seconds_fine)) /
  base::sum(data_box_batches |> dplyr::pull(n_positions))


#----------------------------------------------------------#
# 3. Whole-globe costs per batch -----
#----------------------------------------------------------#

data_events_global <-
  readr::read_csv(
    file = base::file.path(path_run_global, "events.csv"),
    col_names = c("fn_name", "kind", "epoch", "extras"),
    col_types = "ccdc"
  ) |>
  dplyr::filter(fn_name == "get_gridpoints_link") |>
  dplyr::mutate(
    call_id = 1L + base::cumsum(dplyr::lag(kind == "exit", default = FALSE))
  ) |>
  dplyr::mutate(
    step_order = base::cumsum(kind == "step"),
    seconds = dplyr::lead(epoch) - epoch,
    .by = call_id
  )

data_global_coarse <-
  data_events_global |>
  dplyr::summarise(
    n_candidates = dplyr::last(extras) |>
      stringr::str_extract("(?<=;data_source_gridpoints=)[0-9]+") |>
      base::as.numeric(),
    seconds_coarse = base::sum(
      seconds[
        kind == "step" &
          step_order == purrr::chuck(vec_step_order, "coarse")
      ]
    ),
    .by = call_id
  ) |>
  dplyr::filter(n_candidates == base::max(n_candidates))

data_global_filter <-
  readr::read_csv(
    file = base::file.path(path_run_global, "batch_runs.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::filter(candidates == "global")

data_global_info <-
  readr::read_csv(
    file = base::file.path(path_run_global, "run_info.csv"),
    show_col_types = FALSE
  )


#----------------------------------------------------------#
# 4. Write and read costs -----
#----------------------------------------------------------#

data_write_batches <-
  readr::read_csv(
    file = base::file.path(path_run_writes, "write_batches.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::mutate(n_rows = row_to - row_from + 1)

data_write_summary <-
  readr::read_csv(
    file = base::file.path(path_run_writes, "write_summary.csv"),
    show_col_types = FALSE
  )

n_links_subset <-
  data_write_summary |>
  dplyr::pull(n_rows_written) |>
  purrr::chuck(1L)

# Insert cost per row into the indexed table at the largest size measured
#   (the last three batches of `copy_to_no_analyze`)
seconds_per_row_insert <-
  data_write_batches |>
  dplyr::filter(variant == "copy_to_no_analyze") |>
  dplyr::slice_max(order_by = write_batch, n = 3L) |>
  dplyr::summarise(
    value = base::sum(seconds) / base::sum(n_rows)
  ) |>
  dplyr::pull(value)

# `ANALYZE` cost per row of the link table, from the one full `ANALYZE`
seconds_per_row_analyze <-
  data_write_summary |>
  dplyr::filter(variant == "append_then_index") |>
  dplyr::pull(seconds_analyze_full) /
  n_links_subset

seconds_per_row_append <-
  data_write_summary |>
  dplyr::filter(variant == "append_then_index") |>
  dplyr::mutate(
    value = (seconds_writes + seconds_index_last) / n_rows_written
  ) |>
  dplyr::pull(value)

# Read rates in rows per second (median of the repetitions)
data_read_rates <-
  readr::read_csv(
    file = base::file.path(path_run_writes, "read_runs.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::summarise(
    rows_per_second = stats::median(n_rows / seconds_read),
    .by = read_name
  )

value_rate <-
  data_read_rates |>
  dplyr::select(read_name, rows_per_second) |>
  tibble::deframe()

# Rows read per batch by the v1 writers (see the v1 functions named):
#   add_samples_id(): Samples distinct names, Samples id and name;
#   add_to_db() on Samples: Samples all columns and the duplicate test;
#   add_abiotic_data_ref(): Samples id and name;
#   add_dataset_sample(): DatasetSample ids;
#   add_datasets() and add_to_db() on Datasets: Datasets three times.
seconds_reads_per_batch <-
  n_samples_v1_mean / purrr::chuck(value_rate, "samples_distinct_names") +
  2 * n_samples_v1_mean / purrr::chuck(value_rate, "samples_id_name") +
  n_samples_v1_mean / purrr::chuck(value_rate, "samples_all_columns") +
  n_samples_v1_mean / purrr::chuck(value_rate, "dataset_sample_ids") +
  3 * n_datasets_v1 / purrr::chuck(value_rate, "datasets_all_columns")


#----------------------------------------------------------#
# 5. Terms of the full-size estimate -----
#----------------------------------------------------------#

n_pairs_v1 <-
  purrr::chuck(vec_pairs_per_position, "n_age0") * n_positions_v1_age0 +
  purrr::chuck(vec_pairs_per_position, "n_other") * n_positions_v1_other

# `ANALYZE` after every batch reads the whole table so far; with equal
#   batches the rows read sum to n_links * (n_batches + 1) / 2
n_rows_analyzed_v1 <-
  n_links_v1 * (n_batches_v1 + 1) / 2

seconds_coarse_mean <-
  data_global_coarse |>
  dplyr::pull(seconds_coarse) |>
  base::mean()

table_terms <-
  tibble::tribble(
    ~term, ~method, ~unit_cost_seconds, ~n_units_v1,
    "coarse filter (whole-globe candidates)",
    stringr::str_c(
      "mean seconds per batch of 3 batches against the 53.4 M ",
      "candidates x v1 batches"
    ),
    seconds_coarse_mean, n_batches_v1,
    "fine filter",
    "seconds per position (full box) x v1 positions",
    seconds_fine_per_position, n_positions_v1,
    "distance (one distGeo call per pair)",
    stringr::str_c(
      "seconds per pair (full box) x v1 pairs (pairs per position by ",
      "age class, fitted on the 12 full-box batches)"
    ),
    seconds_per_pair, n_pairs_v1,
    "import filter on the whole-globe table",
    "mean seconds per batch of 3 batches x v1 batches",
    data_global_filter |>
      dplyr::pull(seconds_filter) |>
      base::mean(),
    n_batches_v1,
    "link inserts into the indexed table",
    stringr::str_c(
      "seconds per row at 36 to 48 M rows (copy_to without ANALYZE) ",
      "x v1 links"
    ),
    seconds_per_row_insert, n_links_v1,
    "ANALYZE of the link table after every batch",
    stringr::str_c(
      "seconds per row of one full ANALYZE x rows analysed over all ",
      "v1 batches"
    ),
    seconds_per_row_analyze, n_rows_analyzed_v1,
    "whole-table reads of the writers",
    stringr::str_c(
      "rows read per batch at mean v1 table size / measured read ",
      "rates x v1 batches"
    ),
    seconds_reads_per_batch, n_batches_v1,
    "one-off: build and deduplicate the whole-globe candidates",
    "measured once at full size (09)",
    data_global_info |>
      dplyr::mutate(
        value = seconds_build_global + seconds_distinct_global
      ) |>
      dplyr::pull(value),
    1
  ) |>
  dplyr::mutate(
    seconds_v1 = unit_cost_seconds * n_units_v1,
    hours_v1 = seconds_v1 / 3600,
    share = seconds_v1 / base::sum(seconds_v1),
    kind = "extrapolated lower bound"
  ) |>
  dplyr::arrange(dplyr::desc(seconds_v1))

# The alternative write path, for comparison with the two write terms
table_write_alternative <-
  tibble::tibble(
    term = "link writes: append without indexes, then build both indexes",
    unit_cost_seconds = seconds_per_row_append,
    n_units_v1 = n_links_v1,
    seconds_v1 = seconds_per_row_append * n_links_v1,
    hours_v1 = seconds_per_row_append * n_links_v1 / 3600,
    kind = "extrapolated lower bound"
  )

data_inputs <-
  tibble::tibble(
    run_box = base::basename(path_run_box),
    run_global = base::basename(path_run_global),
    run_writes = base::basename(path_run_writes),
    n_positions_v1 = n_positions_v1,
    n_positions_v1_age0 = n_positions_v1_age0,
    n_positions_v1_other = n_positions_v1_other,
    n_batches_v1 = n_batches_v1,
    n_links_v1 = n_links_v1,
    pairs_per_position_age0 = purrr::chuck(
      vec_pairs_per_position, "n_age0"
    ),
    pairs_per_position_other = purrr::chuck(
      vec_pairs_per_position, "n_other"
    ),
    pairs_fit_r_squared = base::summary(mod_pairs) |>
      purrr::chuck("r.squared"),
    n_pairs_v1 = n_pairs_v1,
    microseconds_per_pair = seconds_per_pair * 1e6
  )


#----------------------------------------------------------#
# 6. Save -----
#----------------------------------------------------------#

list_outputs <-
  list(
    stage06_terms = table_terms,
    stage06_write_alternative = table_write_alternative,
    stage06_inputs = data_inputs,
    box_batches = data_box_batches_classed,
    global_coarse = data_global_coarse
  )

purrr::iwalk(
  .x = list_outputs,
  .f = ~ readr::write_csv(
    x = .x,
    file = base::file.path(path_output, stringr::str_c(.y, ".csv"))
  )
)

cli::cli_inform(
  c(
    "v" = "Extrapolated the v1 gridpoint stage to full size.",
    "i" = "Results saved to {.path {path_output}}."
  )
)
