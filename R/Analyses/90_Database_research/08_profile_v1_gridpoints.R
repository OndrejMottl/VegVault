#----------------------------------------------------------#
#
#
#                       VegVault
#
#           Profile the v1 gridpoint stage on a nested box
#        - v1 functions unchanged, on a disposable database
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Run the v1 gridpoint stage (R/02_Main_analyses/06_Create_gridpoints.R)
#   and one current-climate import (the bio1 call of
#   R/02_Main_analyses/07_Import_chelsa_neo_climate_data.R) on a copy of
#   the pre-gridpoint database of one nested box, built by
#   07_prepare_profiling_inputs.R. The v1 functions run unchanged; base
#   `trace()` adds a timestamp before every top-level step of each listed
#   function and at its exit, with the row counts of the data frames in
#   its frame. `Rprof()` samples the whole run as a cross-check.
#
# Deviations from the v1 build, which the profile reports:
#   - Gridpoint candidates are the cells of the box plus the subset margin,
#     not the whole globe, so the coarse filter scans a smaller table;
#     09_profile_v1_global_batches.R times it at global size.
#   - The pre-gridpoint database holds only the datasets of the box, so the
#     whole-table reads in the writers read smaller tables.
#   - The inputs are read from local `.rds` copies of the v1.1.0 artefacts
#     (via a `file://` URL for the current-climate import), not downloaded.
#
# Each run writes a new folder `run_<timestamp>` under the box folder and
#   never overwrites. v1.0.0 is not opened.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/08_profile_v1_gridpoints.R <box>
#   where <box> is a name under `profiling: boxes:` in
#   research_settings.yml.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (also sources the v1 functions)
source(
  here::here("R/00_Config_file.R")
)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 1L,
  msg = "Give one box name from research_settings.yml."
)

name_box <-
  purrr::chuck(vec_args, 1L)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_subset <-
  purrr::chuck(list_settings, "subset")

list_settings_profiling <-
  purrr::chuck(list_settings, "profiling")

list_box <-
  purrr::chuck(list_settings_profiling, "boxes", name_box)

path_research <-
  here::here("Data", "Temp", "Database_research")

path_subset <-
  base::file.path(
    path_research,
    "Subset",
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings_subset, "box_name"),
      ".sqlite"
    )
  )

path_profiling <-
  base::file.path(path_research, "Profiling")

path_inputs <-
  base::file.path(path_profiling, "Inputs")

path_template <-
  base::file.path(path_profiling, name_box, "pre_gridpoints.sqlite")

time_run_start <-
  base::Sys.time()

path_run <-
  base::file.path(
    path_profiling,
    name_box,
    stringr::str_c("run_", base::format(time_run_start, "%Y%m%d_%H%M%S"))
  )

path_run_db <-
  base::file.path(path_run, "gridpoints.sqlite")

path_event_log <-
  base::file.path(path_run, "events.csv")

path_rprof <-
  base::file.path(path_run, "rprof.out")

# The v1 functions timed; each is traced at every top-level step
vec_functions_traced <-
  c(
    "add_dataset_type",
    "add_dataset_source_type",
    "add_data_source",
    "add_gridpoints_with_links",
    "get_gridpoints_link",
    "get_valid_gridpoints_ids",
    "add_datasets",
    "add_samples",
    "add_samples_id",
    "add_sample_size_id",
    "add_sample_reference_id",
    "add_samples_reference",
    "add_dataset_sample",
    "add_abiotic_data_ref",
    "add_to_db",
    "add_chelsa_neo_data",
    "dowload_and_load",
    "add_abiotic_variable",
    "add_sample_abiotic_value"
  )

assertthat::assert_that(
  base::file.exists(path_template),
  msg = "The box database does not exist; run 07_prepare_profiling_inputs.R."
)

assertthat::assert_that(
  base::all(
    purrr::map_lgl(
      .x = vec_functions_traced,
      .f = ~ base::exists(.x, envir = base::globalenv(), mode = "function")
    )
  ),
  msg = "A v1 function to trace is not loaded."
)

assertthat::assert_that(
  base::isFALSE(base::dir.exists(path_run)),
  msg = "The run folder exists already."
)

base::dir.create(path = path_run, recursive = TRUE)

# The run database is a new copy inside the profiling folder
assertthat::assert_that(
  base::file.copy(from = path_template, to = path_run_db, overwrite = FALSE),
  msg = "Copying the box database failed."
)

assertthat::assert_that(
  base::isFALSE(
    base::identical(
      base::normalizePath(path_run_db),
      base::normalizePath(path_to_vegvault, mustWork = FALSE)
    )
  ),
  msg = "The run database must not be the v1.0.0 file."
)


#----------------------------------------------------------#
# 1. Gridpoint input of the box, built as in v1 -----
#----------------------------------------------------------#

time_data_raw_start <-
  base::Sys.time()

data_coord <-
  readr::read_rds(
    file = base::file.path(path_inputs, "gridpoint_coords_global.rds")
  ) |>
  dplyr::filter(
    long >= purrr::chuck(list_box, "lon_min") -
      purrr::chuck(list_settings_subset, "margin_lon"),
    long <= purrr::chuck(list_box, "lon_max") +
      purrr::chuck(list_settings_subset, "margin_lon"),
    lat >= purrr::chuck(list_box, "lat_min") -
      purrr::chuck(list_settings_subset, "margin_lat"),
    lat <= purrr::chuck(list_box, "lat_max") +
      purrr::chuck(list_settings_subset, "margin_lat")
  )

vec_age <-
  readr::read_rds(
    file = base::file.path(path_inputs, "gridpoint_ages.rds")
  )

# The "Datasets" section of R/02_Main_analyses/06_Create_gridpoints.R,
#   with `paste()` written as `stringr::str_c()` (same character output)
data_raw <-
  tidyr::expand_grid(
    data_coord,
    vec_age
  ) |>
  dplyr::mutate(
    dataset_type = "gridpoints",
    dataset_source_type = "gridpoints",
    data_source_type_reference =
      "gridpoints - artificially created by O. Mottl",
    data_source_desc = "gridpoints",
    data_source_reference = "gridpoints - artificially created by O. Mottl",
    dataset_reference = "gridpoints - artificially created by O. Mottl",
    coord_long = base::as.numeric(long),
    coord_lat = base::as.numeric(lat),
    age = base::as.numeric(vec_age)
  ) |>
  dplyr::select(-c("vec_age", "long", "lat")) |>
  tidyr::nest(
    data_samples = c(
      "age"
    )
  ) |>
  dplyr::mutate(
    dataset_name = stringr::str_c(
      "geo",
      base::round(coord_long, digits = 2),
      base::round(coord_lat, digits = 2),
      sep = "_"
    )
  ) |>
  tidyr::unnest("data_samples") |>
  dplyr::mutate(
    sample_name = stringr::str_c(
      dataset_name,
      "_",
      age
    ),
    sample_size = NA_real_,
    description = "gridpoint",
    sample_reference = "gridpoints - artificially created by O. Mottl"
  )

seconds_data_raw <-
  base::difftime(
    base::Sys.time(),
    time_data_raw_start,
    units = "secs"
  ) |>
  base::as.numeric()


#----------------------------------------------------------#
# 2. Trace the v1 functions -----
#----------------------------------------------------------#

# Adds `data_trace_steps` and traces `vec_functions_traced`
source(
  here::here("R/Analyses/90_Database_research/08a_trace_v1_functions.R")
)


#----------------------------------------------------------#
# 3. Run the stage on the run database -----
#----------------------------------------------------------#

con_run <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_run_db
  )

tryCatch(
  expr = {
    # References of bio1 as stored in v1, so the import call is identical
    #   to the v1 call
    vec_bio1_references <-
      DBI::dbGetQuery(
        conn = con_run,
        statement = stringr::str_c(
          "SELECT r.reference_detail FROM AbioticVariable v ",
          "JOIN AbioticVariableReference vr ",
          "ON vr.abiotic_variable_id = v.abiotic_variable_id ",
          "JOIN \"References\" r ON r.reference_id = vr.reference_id ",
          "WHERE v.abiotic_variable_name = 'bio1'"
        )
      ) |>
      dplyr::pull(reference_detail)

    utils::Rprof(filename = path_rprof, interval = 0.02)

    time_stage06_start <-
      base::Sys.time()

    data_dataset_type_db <-
      add_dataset_type(
        data_source = data_raw,
        con = con_run
      )

    data_dataset_source_type_db <-
      add_dataset_source_type(
        data_source = data_raw,
        con = con_run
      )

    data_data_source_id_db <-
      add_data_source(
        data_source = data_raw,
        con = con_run
      )

    add_gridpoints_with_links(
      data_source = data_raw,
      sel_con = con_run,
      dataset_type_db = data_dataset_type_db,
      dataset_source_type_db = data_dataset_source_type_db,
      data_source_id_db = data_data_source_id_db,
      sel_grid_size_degree = purrr::chuck(
        list_settings_profiling, "grid_size_degree"
      ),
      sel_distance_km = purrr::chuck(list_settings_profiling, "distance_km"),
      sel_distance_years = purrr::chuck(
        list_settings_profiling, "distance_years"
      )
    )

    seconds_stage06 <-
      base::difftime(
        base::Sys.time(),
        time_stage06_start,
        units = "secs"
      ) |>
      base::as.numeric()

    time_stage07_start <-
      base::Sys.time()

    # The whole-globe artefact, as in v1
    add_chelsa_neo_data(
      sel_con = con_run,
      sel_url = stringr::str_c(
        "file:///",
        base::normalizePath(
          base::file.path(path_inputs, "chelsa_neo_bio01_global.rds"),
          winslash = "/"
        )
      ),
      sel_var_name = "bio1",
      sel_var_unit = "C (degree Celsius)",
      sel_var_reference = list(vec_bio1_references),
      sel_var_detail = "mean annual air temperature"
    )

    seconds_stage07 <-
      base::difftime(
        base::Sys.time(),
        time_stage07_start,
        units = "secs"
      ) |>
      base::as.numeric()
  },
  finally = {
    utils::Rprof(filename = NULL)

    purrr::walk(
      .x = vec_functions_traced,
      .f = ~ base::untrace(what = .x, where = base::globalenv())
    )

    DBI::dbDisconnect(con_run)
  }
)


#----------------------------------------------------------#
# 4. Compare the links with v1 -----
#----------------------------------------------------------#

# Links are compared by sample name and gridpoint sample name, because the
#   new gridpoint samples get new ids. The box samples keep their v1 ids.
time_validation_start <-
  base::Sys.time()

con_check <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_run_db,
    flags = RSQLite::SQLITE_RO
  )

data_validation <-
  tryCatch(
    expr = {
      DBI::dbExecute(
        conn = con_check,
        statement = "ATTACH DATABASE ? AS v1_subset",
        params = list(path_subset)
      )

      DBI::dbGetQuery(
        conn = con_check,
        statement = stringr::str_c(
          "WITH ",
          "box_samples AS (SELECT ds.sample_id FROM main.DatasetSample ds ",
          "JOIN main.Datasets d ON d.dataset_id = ds.dataset_id ",
          "WHERE d.dataset_type_id != 4), ",
          "links_run AS (SELECT a.sample_id, g.sample_name AS grid_name, ",
          "a.distance_in_km AS km, a.distance_in_years AS years ",
          "FROM main.AbioticDataReference a ",
          "JOIN main.Samples g ON g.sample_id = a.sample_ref_id), ",
          "links_v1 AS (SELECT a.sample_id, g.sample_name AS grid_name, ",
          "a.distance_in_km AS km, a.distance_in_years AS years ",
          "FROM v1_subset.AbioticDataReference a ",
          "JOIN v1_subset.Samples g ON g.sample_id = a.sample_ref_id ",
          "WHERE a.sample_id IN (SELECT sample_id FROM box_samples)) ",
          "SELECT ",
          "(SELECT count(*) FROM links_run) AS n_links_run, ",
          "(SELECT count(*) FROM links_v1) AS n_links_v1, ",
          "(SELECT count(*) FROM (SELECT sample_id, grid_name ",
          "FROM links_run EXCEPT SELECT sample_id, grid_name ",
          "FROM links_v1)) AS n_pairs_only_run, ",
          "(SELECT count(*) FROM (SELECT sample_id, grid_name ",
          "FROM links_v1 EXCEPT SELECT sample_id, grid_name ",
          "FROM links_run)) AS n_pairs_only_v1, ",
          "(SELECT count(*) FROM (SELECT * FROM links_run ",
          "EXCEPT SELECT * FROM links_v1)) AS n_rows_differing"
        )
      ) |>
        tibble::as_tibble()
    },
    finally = DBI::dbDisconnect(con_check)
  )

seconds_validation <-
  base::difftime(
    base::Sys.time(),
    time_validation_start,
    units = "secs"
  ) |>
  base::as.numeric()


#----------------------------------------------------------#
# 5. Summarise the events -----
#----------------------------------------------------------#

# Adds `data_events`, `table_steps`, and `table_calls`
source(
  here::here(
    "R/Analyses/90_Database_research/08b_summarise_trace_events.R"
  )
)


list_rprof <-
  utils::summaryRprof(filename = path_rprof)

table_rprof_total <-
  purrr::chuck(list_rprof, "by.total") |>
  tibble::rownames_to_column(var = "fn_name") |>
  tibble::as_tibble() |>
  dplyr::slice_head(n = 60)

table_rprof_self <-
  purrr::chuck(list_rprof, "by.self") |>
  tibble::rownames_to_column(var = "fn_name") |>
  tibble::as_tibble() |>
  dplyr::slice_head(n = 60)


#----------------------------------------------------------#
# 6. Save results -----
#----------------------------------------------------------#

data_run_info <-
  tibble::tibble(
    script = "08_profile_v1_gridpoints.R",
    box_name = name_box,
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    n_gridpoint_cells = base::nrow(data_coord),
    n_gridpoint_ages = base::length(vec_age),
    n_gridpoint_candidates = base::nrow(data_raw),
    seconds_data_raw = seconds_data_raw,
    seconds_stage06 = seconds_stage06,
    seconds_stage07_bio1 = seconds_stage07,
    seconds_validation = seconds_validation,
    n_trace_events = base::nrow(data_events),
    run_db_size_bytes = base::file.size(path_run_db),
    r_version = base::as.character(base::getRversion()),
    sqlite_version = RSQLite::rsqliteVersion() |>
      purrr::chuck(2L)
  )

list_outputs <-
  list(
    run_info = data_run_info,
    validation_links = data_validation,
    trace_steps = data_trace_steps,
    step_summary = table_steps,
    call_summary = table_calls,
    rprof_by_total = table_rprof_total,
    rprof_by_self = table_rprof_self
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
    "v" = "Profiled box {name_box}: stage 06 in {round(seconds_stage06)} s.",
    "i" = "Results saved to {.path {path_run}}."
  )
)
