#----------------------------------------------------------#
#
#
#                       VegVault
#
#     Time v1 gridpoint batches against the global candidates
#        - v1 functions unchanged, no database written
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# The v1 gridpoint stage passes the whole-globe gridpoint table (every
#   cell of the climate grid x every age) to get_gridpoints_link() for each
#   batch of 500 sample positions, and filters the whole-globe table again
#   for the gridpoints to import. 08_profile_v1_gridpoints.R runs with the
#   candidates of a box only. This script measures the whole-globe costs
#   for a few batches of the full subset box:
#   - the one-time preparation in add_gridpoints_with_links() (`distinct()`
#     of the whole-globe table),
#   - get_gridpoints_link() against the whole-globe table and against the
#     box table (traced per step, as in 08),
#   - the import filter on the whole-globe table and on the box table.
#   The whole-globe table here has only the columns the batch steps use,
#   so the import filter is a lower bound for v1, whose table had 15
#   columns. The box database is opened read-only and nothing is written
#   to any database. Peak memory is about 10 to 15 GB.
#
# Each run writes a new folder `run_<timestamp>` under `Profiling/global`
#   and never overwrites. v1.0.0 is not opened.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (also sources the v1 functions)
source(
  here::here("R/00_Config_file.R")
)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_subset <-
  purrr::chuck(list_settings, "subset")

list_settings_profiling <-
  purrr::chuck(list_settings, "profiling")

name_box <-
  purrr::chuck(list_settings_subset, "box_name")

list_box <-
  purrr::chuck(list_settings_profiling, "boxes", name_box)

path_profiling <-
  here::here("Data", "Temp", "Database_research", "Profiling")

path_inputs <-
  base::file.path(path_profiling, "Inputs")

path_template <-
  base::file.path(path_profiling, name_box, "pre_gridpoints.sqlite")

time_run_start <-
  base::Sys.time()

path_run <-
  base::file.path(
    path_profiling,
    "global",
    stringr::str_c("run_", base::format(time_run_start, "%Y%m%d_%H%M%S"))
  )

path_event_log <-
  base::file.path(path_run, "events.csv")

vec_functions_traced <-
  c("get_gridpoints_link", "get_valid_gridpoints_ids")

n_batches_timed <-
  purrr::chuck(list_settings_profiling, "n_global_batches")

assertthat::assert_that(
  base::file.exists(path_template),
  msg = "The box database does not exist; run 07_prepare_profiling_inputs.R."
)

assertthat::assert_that(
  base::isFALSE(base::dir.exists(path_run)),
  msg = "The run folder exists already."
)

base::dir.create(path = path_run, recursive = TRUE)

# Reset the maximum-memory counter of R
data_memory_start <-
  base::gc(reset = TRUE)


#----------------------------------------------------------#
# 1. Whole-globe gridpoint candidates, as in v1 -----
#----------------------------------------------------------#

time_build_start <-
  base::Sys.time()

vec_age <-
  readr::read_rds(
    file = base::file.path(path_inputs, "gridpoint_ages.rds")
  )

# The columns of the v1 gridpoint table that the batch steps use, named as
#   in R/02_Main_analyses/06_Create_gridpoints.R
data_gridpoints_raw_global <-
  readr::read_rds(
    file = base::file.path(path_inputs, "gridpoint_coords_global.rds")
  ) |>
  dplyr::mutate(
    dataset_name = stringr::str_c(
      "geo",
      base::round(long, digits = 2),
      base::round(lat, digits = 2),
      sep = "_"
    )
  ) |>
  tidyr::expand_grid(age = vec_age) |>
  dplyr::transmute(
    dataset_name,
    sample_name = stringr::str_c(dataset_name, "_", age),
    coord_long = base::as.numeric(long),
    coord_lat = base::as.numeric(lat),
    age = base::as.numeric(age)
  )

seconds_build_global <-
  base::difftime(
    base::Sys.time(),
    time_build_start,
    units = "secs"
  ) |>
  base::as.numeric()

# The one-time preparation in add_gridpoints_with_links()
time_distinct_start <-
  base::Sys.time()

data_gridpoints_to_limit_global <-
  data_gridpoints_raw_global |>
  dplyr::distinct(sample_name, coord_long, coord_lat, age) |>
  dplyr::rename(sample = "sample_name") |>
  dplyr::rename_with(~ stringr::str_c("grid_", .x))

seconds_distinct_global <-
  base::difftime(
    base::Sys.time(),
    time_distinct_start,
    units = "secs"
  ) |>
  base::as.numeric()

# The candidates of the box, as passed in 08_profile_v1_gridpoints.R
data_gridpoints_to_limit_box <-
  data_gridpoints_to_limit_global |>
  dplyr::filter(
    grid_coord_long >= purrr::chuck(list_box, "lon_min") -
      purrr::chuck(list_settings_subset, "margin_lon"),
    grid_coord_long <= purrr::chuck(list_box, "lon_max") +
      purrr::chuck(list_settings_subset, "margin_lon"),
    grid_coord_lat >= purrr::chuck(list_box, "lat_min") -
      purrr::chuck(list_settings_subset, "margin_lat"),
    grid_coord_lat <= purrr::chuck(list_box, "lat_max") +
      purrr::chuck(list_settings_subset, "margin_lat")
  )

data_gridpoints_raw_box <-
  data_gridpoints_raw_global |>
  dplyr::filter(
    sample_name %in% (
      data_gridpoints_to_limit_box |>
        dplyr::pull(grid_sample)
    )
  )


#----------------------------------------------------------#
# 2. Batches of the full box, as in v1 -----
#----------------------------------------------------------#

con_box <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_template,
    flags = RSQLite::SQLITE_RO
  )

# The first query of add_gridpoints_with_links()
data_bd_vegetation_raw <-
  tryCatch(
    expr = {
      dplyr::tbl(con_box, "Datasets") |>
        dplyr::filter(dataset_type_id != 4) |>
        dplyr::inner_join(
          dplyr::tbl(con_box, "DatasetSample"),
          by = dplyr::join_by("dataset_id")
        ) |>
        dplyr::left_join(
          dplyr::tbl(con_box, "Samples") |>
            dplyr::select("sample_id", "sample_name", "age"),
          by = dplyr::join_by("sample_id")
        ) |>
        dplyr::select(
          "dataset_name",
          "sample_name",
          "coord_long", "coord_lat",
          "age"
        ) |>
        dplyr::distinct() |>
        dplyr::collect()
    },
    finally = DBI::dbDisconnect(con_box)
  )

# The nesting and batching of add_gridpoints_with_links()
data_bd_vegetation_nest <-
  data_bd_vegetation_raw |>
  dplyr::distinct(
    dataset_name, sample_name,
    coord_long, coord_lat,
    age
  ) |>
  dplyr::group_by(coord_long, coord_lat, age) |>
  tidyr::nest(data = -c("coord_long", "coord_lat", "age")) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    geo_veg_sample = stringr::str_c("dummy_", dplyr::row_number())
  )

data_bd_vegetation_nest_ref <-
  data_bd_vegetation_nest |>
  dplyr::select("geo_veg_sample", "data") |>
  tidyr::unnest(data)

data_bd_vegetation_batches <-
  data_bd_vegetation_nest |>
  dplyr::select("geo_veg_sample", "coord_long", "coord_lat", "age") |>
  dplyr::mutate(
    batch = 1L + (dplyr::row_number() - 1L) %/% 500L
  )

n_batches_box <-
  data_bd_vegetation_batches |>
  dplyr::pull(batch) |>
  base::max()

# Batches spread evenly over the stage, first and last included
vec_batches_timed <-
  base::seq(from = 1, to = n_batches_box, length.out = n_batches_timed) |>
  base::round() |>
  base::as.integer() |>
  base::unique()


#----------------------------------------------------------#
# 3. Time the batches -----
#----------------------------------------------------------#

# Adds `data_trace_steps` and traces `vec_functions_traced`
source(
  here::here("R/Analyses/90_Database_research/08a_trace_v1_functions.R")
)

# Each batch runs against the whole-globe table, then against the box
#   table; the order of the runs is the order of the traced calls
data_runs <-
  tidyr::expand_grid(
    batch = vec_batches_timed,
    candidates = c("global", "box")
  )

data_run_results <-
  tryCatch(
    expr = {
      data_runs |>
        dplyr::mutate(
          result = purrr::map2(
            .x = batch,
            .y = candidates,
            .f = ~ {
              data_batch <-
                data_bd_vegetation_batches |>
                dplyr::filter(batch == .x) |>
                dplyr::select(-"batch")

              data_candidates <-
                list(
                  global = data_gridpoints_to_limit_global,
                  box = data_gridpoints_to_limit_box
                ) |>
                purrr::chuck(.y)

              data_raw_filtered <-
                list(
                  global = data_gridpoints_raw_global,
                  box = data_gridpoints_raw_box
                ) |>
                purrr::chuck(.y)

              time_link_start <-
                base::Sys.time()

              data_res_link <-
                get_gridpoints_link(
                  data_source = data_batch,
                  data_source_gridpoints = data_candidates,
                  sel_grid_size_degree = purrr::chuck(
                    list_settings_profiling, "grid_size_degree"
                  ),
                  sel_distance_km = purrr::chuck(
                    list_settings_profiling, "distance_km"
                  ),
                  sel_distance_years = purrr::chuck(
                    list_settings_profiling, "distance_years"
                  )
                )

              time_join_start <-
                base::Sys.time()

              # The steps of the batch loop before the database writes
              data_sample_link_to_import <-
                dplyr::left_join(
                  data_res_link,
                  data_bd_vegetation_nest_ref,
                  by = "geo_veg_sample",
                  relationship = "many-to-many"
                ) |>
                dplyr::select(
                  "sample_name",
                  sample_name_gridpoints = "grid_sample",
                  "distance_in_km",
                  "distance_in_years"
                )

              vec_unique_samples_gridpoints <-
                data_sample_link_to_import |>
                dplyr::distinct(sample_name_gridpoints) |>
                dplyr::pull(sample_name_gridpoints)

              time_filter_start <-
                base::Sys.time()

              data_to_import <-
                data_raw_filtered |>
                dplyr::filter(sample_name %in% vec_unique_samples_gridpoints)

              time_filter_end <-
                base::Sys.time()

              tibble::tibble(
                n_positions = base::nrow(data_batch),
                n_candidates = base::nrow(data_candidates),
                n_position_links = base::nrow(data_res_link),
                n_sample_links = base::nrow(data_sample_link_to_import),
                n_gridpoints_imported = base::nrow(data_to_import),
                seconds_link = base::difftime(
                  time_join_start, time_link_start, units = "secs"
                ) |>
                  base::as.numeric(),
                seconds_join = base::difftime(
                  time_filter_start, time_join_start, units = "secs"
                ) |>
                  base::as.numeric(),
                seconds_filter = base::difftime(
                  time_filter_end, time_filter_start, units = "secs"
                ) |>
                  base::as.numeric(),
                links = list(
                  data_res_link |>
                    dplyr::select(geo_veg_sample, grid_sample)
                )
              )
            }
          )
        ) |>
        tidyr::unnest(cols = result)
    },
    finally = purrr::walk(
      .x = vec_functions_traced,
      .f = ~ base::untrace(what = .x, where = base::globalenv())
    )
  )

data_memory_end <-
  base::gc()


#----------------------------------------------------------#
# 4. Summarise -----
#----------------------------------------------------------#

# Adds `data_events`, `table_steps`, and `table_calls`
source(
  here::here(
    "R/Analyses/90_Database_research/08b_summarise_trace_events.R"
  )
)

# The links of a batch must not depend on the candidate table
table_link_agreement <-
  data_run_results |>
  dplyr::select(batch, candidates, links) |>
  tidyr::pivot_wider(names_from = candidates, values_from = links) |>
  dplyr::mutate(
    n_only_global = purrr::map2_int(
      .x = global,
      .y = box,
      .f = ~ dplyr::anti_join(
        x = .x,
        y = .y,
        by = dplyr::join_by(geo_veg_sample, grid_sample)
      ) |>
        base::nrow()
    ),
    n_only_box = purrr::map2_int(
      .x = box,
      .y = global,
      .f = ~ dplyr::anti_join(
        x = .x,
        y = .y,
        by = dplyr::join_by(geo_veg_sample, grid_sample)
      ) |>
        base::nrow()
    )
  ) |>
  dplyr::select(batch, n_only_global, n_only_box)

table_runs <-
  data_run_results |>
  dplyr::select(-links)

data_run_info <-
  tibble::tibble(
    script = "09_profile_v1_global_batches.R",
    box_name = name_box,
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    n_gridpoint_candidates_global = base::nrow(
      data_gridpoints_to_limit_global
    ),
    n_gridpoint_candidates_box = base::nrow(data_gridpoints_to_limit_box),
    n_positions_box = base::nrow(data_bd_vegetation_batches),
    n_batches_box = n_batches_box,
    batches_timed = stringr::str_c(vec_batches_timed, collapse = " "),
    seconds_build_global = seconds_build_global,
    seconds_distinct_global = seconds_distinct_global,
    # The last column of `gc()` is the maximum used, in Mb
    max_memory_mb = data_memory_end[, base::ncol(data_memory_end)] |>
      base::sum(),
    r_version = base::as.character(base::getRversion())
  )

list_outputs <-
  list(
    run_info = data_run_info,
    batch_runs = table_runs,
    link_agreement = table_link_agreement,
    trace_steps = data_trace_steps,
    step_summary = table_steps,
    call_summary = table_calls
  )

purrr::iwalk(
  .x = list_outputs,
  .f = ~ readr::write_csv(
    x = .x,
    file = base::file.path(path_run, stringr::str_c(.y, ".csv"))
  )
)

cli::cli_inform(
  c(
    "v" = "Timed {length(vec_batches_timed)} batch{?es} at global size.",
    "i" = "Results saved to {.path {path_run}}."
  )
)
