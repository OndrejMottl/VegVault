#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Benchmark three build engines on the regional subset
#             - one child process per engine run
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Build the same output from the regional subset with three engines
#   (17a_run_build_engine.R: r_memory, sqlite_incremental and duckdb) and
#   compare wall time, peak memory, ids and resuming:
#   1. Prepare the shared inputs: the global CHELSA cells with their bio1
#      value at age 0, the gridpoint ages, and the id of bio1.
#   2. Install the DuckDB extensions `spatial` and `sqlite` into the
#      configured folder if they are missing (a download from the official
#      DuckDB repository), and check that DuckDB's geodesic distance
#      matches geosphere::distGeo().
#   3. Run every engine `n_repetitions` times, interleaved, each in a new R
#      process. Then, once each: r_memory and sqlite_incremental with the
#      chunks in reverse order, duckdb with one thread, and a resume test of
#      sqlite_incremental: a run that kills itself in the middle of a chunk,
#      followed by a run that resumes it.
#   4. Fingerprint every table of every output (row count and hash of the
#      sorted rows) and compare them with the first r_memory run; tables
#      that differ get row counts of the difference both ways.
# The subset is opened read-only, and its size, modification time and
#   header are compared before and after. v1.0.0 is not opened. Each call
#   writes a new folder `run_<timestamp>` (or `smoke_<timestamp>`) under
#   `Data/Temp/Database_research/Engines` and overwrites nothing; a failed
#   call is restarted in a new folder.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/17_benchmark_build_engines.R
#     [smoke]
#   With `smoke`, every engine runs once (no repetitions), with the reverse,
#   one-thread and resume runs, to check the code before timing it.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 0L ||
    base::identical(vec_args, "smoke"),
  msg = "The only optional argument is `smoke`."
)

flag_smoke <-
  base::identical(vec_args, "smoke")

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_engines <-
  purrr::chuck(list_settings, "engines")

n_repetitions <-
  if (
    base::isTRUE(flag_smoke)
  ) {
    1L
  } else {
    purrr::chuck(list_settings_engines, "n_repetitions") |>
      base::as.integer()
  }

path_research <-
  here::here("Data", "Temp", "Database_research")

path_subset <-
  base::file.path(
    path_research,
    "Subset",
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings, "subset", "box_name"),
      ".sqlite"
    )
  ) |>
  base::normalizePath(winslash = "/", mustWork = TRUE)

assertthat::assert_that(
  !stringr::str_detect(path_subset, "[ ?#%']"),
  msg = "The subset path holds a character that a URI or SQL would break."
)

time_run_start <-
  base::Sys.time()

path_run <-
  base::file.path(
    path_research,
    "Engines",
    stringr::str_c(
      dplyr::if_else(flag_smoke, "smoke_", "run_"),
      base::format(time_run_start, "%Y%m%d_%H%M%S")
    )
  )

assertthat::assert_that(
  !base::dir.exists(path_run),
  msg = "The run folder exists already."
)

base::dir.create(
  path = base::file.path(path_run, "inputs"),
  recursive = TRUE
)

base::dir.create(
  path = base::file.path(path_run, "logs"),
  recursive = TRUE
)

path_child_script <-
  here::here("R/Analyses/90_Database_research/17a_run_build_engine.R")

path_rscript <-
  base::file.path(base::R.home("bin"), "Rscript")

path_research_library <-
  base::file.path(path_research, "R_library")

path_extension_dir <-
  here::here(purrr::chuck(list_settings_engines, "duckdb_extension_dir"))

base::dir.create(
  path = path_extension_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

path_extension_dir <-
  base::normalizePath(path_extension_dir, winslash = "/", mustWork = TRUE)

# Tables of the output that hold build bookkeeping, not content
vec_bookkeeping_tables <-
  c("BuildChunks", "BuildSteps")


#----------------------------------------------------------#
# 1. Record the subset state; prepare the inputs -----
#----------------------------------------------------------#

vec_subset_header_before <-
  base::readBin(con = path_subset, what = "raw", n = 100L)

size_subset_before <-
  base::file.size(path_subset)

mtime_subset_before <-
  base::file.mtime(path_subset)

if (
  base::as.integer(vec_subset_header_before[19L]) != 1L ||
    base::as.integer(vec_subset_header_before[20L]) != 1L
) {
  cli::cli_abort("The subset is in WAL mode; it was not opened.")
}

# The cell coordinates are those of v1 (rounded to 0.01 degrees); the bio1
#   values carry unrounded coordinates and are matched after rounding, as
#   v1 matched them
data_cell_coords <-
  base::readRDS(here::here(purrr::chuck(list_settings_engines, "cells_file")))

data_bio1 <-
  base::readRDS(here::here(purrr::chuck(list_settings_engines, "bio1_file")))

data_cells <-
  data_cell_coords |>
  dplyr::transmute(
    cell_index = dplyr::row_number(),
    grid_long = long,
    grid_lat = lat
  ) |>
  dplyr::left_join(
    data_bio1 |>
      dplyr::transmute(
        grid_long = base::round(long, 2),
        grid_lat = base::round(lat, 2),
        bio1_value = value
      ),
    by = dplyr::join_by(grid_long, grid_lat),
    multiple = "error",
    unmatched = "error"
  )

data_ages <-
  tibble::tibble(
    grid_age = base::readRDS(
      here::here(purrr::chuck(list_settings_engines, "ages_file"))
    ) |>
      base::sort()
  ) |>
  dplyr::mutate(age_index = dplyr::row_number(), .before = 1L)

con_subset <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_subset,
    flags = RSQLite::SQLITE_RO
  )

value_bio1_id <-
  DBI::dbGetQuery(
    con_subset,
    stringr::str_c(
      "SELECT abiotic_variable_id FROM AbioticVariable ",
      "WHERE abiotic_variable_name = 'bio1'"
    )
  ) |>
  dplyr::pull(abiotic_variable_id)

DBI::dbDisconnect(con_subset)

assertthat::assert_that(
  base::length(value_bio1_id) == 1L,
  msg = "The subset has no single bio1 variable."
)

base::saveRDS(
  object = data_cells,
  file = base::file.path(path_run, "inputs", "cells.rds")
)

base::saveRDS(
  object = data_ages,
  file = base::file.path(path_run, "inputs", "ages.rds")
)

base::saveRDS(
  object = value_bio1_id,
  file = base::file.path(path_run, "inputs", "bio1_variable_id.rds")
)


#----------------------------------------------------------#
# 2. DuckDB extensions and the distance check -----
#----------------------------------------------------------#

base::.libPaths(c(path_research_library, base::.libPaths()))

con_duck_setup <-
  DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))

DBI::dbExecute(
  con_duck_setup,
  stringr::str_c("SET extension_directory = '", path_extension_dir, "'")
)

vec_extensions_installed <-
  DBI::dbGetQuery(
    con_duck_setup,
    stringr::str_c(
      "SELECT extension_name FROM duckdb_extensions() WHERE installed ",
      "AND extension_name IN ('spatial', 'sqlite_scanner')"
    )
  ) |>
  dplyr::pull(extension_name)

if (
  !"spatial" %in% vec_extensions_installed
) {
  cli::cli_inform("Installing the DuckDB extension spatial.")

  DBI::dbExecute(con_duck_setup, "INSTALL spatial")
}

if (
  !"sqlite_scanner" %in% vec_extensions_installed
) {
  cli::cli_inform("Installing the DuckDB extension sqlite.")

  DBI::dbExecute(con_duck_setup, "INSTALL sqlite")
}

DBI::dbExecute(con_duck_setup, "LOAD spatial")

DBI::dbExecute(con_duck_setup, "LOAD sqlite")

# DuckDB 2.0 needs the axis order set; points are (longitude, latitude)
DBI::dbExecute(con_duck_setup, "SET geometry_always_xy = true")

data_duck_versions <-
  DBI::dbGetQuery(
    con_duck_setup,
    stringr::str_c(
      "SELECT extension_name, extension_version, install_mode ",
      "FROM duckdb_extensions() ",
      "WHERE extension_name IN ('spatial', 'sqlite_scanner')"
    )
  ) |>
  tibble::as_tibble() |>
  dplyr::bind_rows(
    tibble::tibble(
      extension_name = "duckdb",
      extension_version = DBI::dbGetQuery(
        con_duck_setup, "SELECT version() AS v"
      ) |>
        dplyr::pull(v)
    )
  )

# The geodesic distance of DuckDB (spatial) against geosphere::distGeo()
#   for a few pairs, including a long one and one across the dateline
data_distance_check <-
  tibble::tribble(
    ~long_a, ~lat_a, ~long_b, ~lat_b,
    -150, 68, -149, 68.3,
    -150, 68, -150, 68.45,
    16, -45, 16.4, -45.2,
    179.9, 70, -179.9, 70.1
  ) |>
  dplyr::mutate(
    distance_geosphere = geosphere::distGeo(
      p1 = base::cbind(long_a, lat_a),
      p2 = base::cbind(long_b, lat_b)
    )
  )

duckdb::duckdb_register(con_duck_setup, "check_r", data_distance_check)

data_distance_check <-
  DBI::dbGetQuery(
    con_duck_setup,
    stringr::str_c(
      "SELECT *, ST_Distance_Spheroid(ST_Point(long_a, lat_a), ",
      "ST_Point(long_b, lat_b)) AS distance_duckdb FROM check_r"
    )
  ) |>
  tibble::as_tibble() |>
  dplyr::mutate(difference_m = distance_duckdb - distance_geosphere)

DBI::dbDisconnect(con_duck_setup, shutdown = TRUE)

readr::write_csv(
  x = data_distance_check,
  file = base::file.path(path_run, "distance_check.csv")
)

readr::write_csv(
  x = data_duck_versions,
  file = base::file.path(path_run, "duckdb_versions.csv")
)

assertthat::assert_that(
  base::all(
    base::abs(data_distance_check |> dplyr::pull(difference_m)) < 0.001
  ),
  msg = "DuckDB and geosphere disagree on geodesic distances."
)


#----------------------------------------------------------#
# 3. Engine runs -----
#----------------------------------------------------------#

vec_engines <-
  c("r_memory", "sqlite_incremental", "duckdb")

# Repetitions are the outer loop; the extra runs come last. The resume
#   test is two calls with the same label: the first kills itself in the
#   middle of chunk 6, the second resumes.
data_runs <-
  dplyr::bind_rows(
    tidyr::expand_grid(
      repetition = base::seq_len(n_repetitions),
      engine = vec_engines
    ) |>
      dplyr::mutate(
        label = stringr::str_c(engine, "_rep", repetition),
        chunk_order = "forward",
        stop_after = 0L,
        duckdb_threads = 0L,
        flag_expect_stop = FALSE
      ),
    tibble::tribble(
      ~engine, ~label, ~chunk_order, ~stop_after, ~duckdb_threads,
      ~flag_expect_stop,
      "r_memory", "r_memory_reverse", "reverse", 0L, 0L, FALSE,
      "sqlite_incremental", "sqlite_incremental_reverse", "reverse", 0L, 0L,
      FALSE,
      "duckdb", "duckdb_threads1", "forward", 0L, 1L, FALSE,
      "sqlite_incremental", "sqlite_incremental_resume", "forward", 5L, 0L,
      TRUE,
      "sqlite_incremental", "sqlite_incremental_resume", "forward", 0L, 0L,
      FALSE
    )
  ) |>
  dplyr::mutate(call = dplyr::row_number(), .before = 1L)

data_run_status <-
  data_runs |>
  dplyr::mutate(
    result = purrr::pmap(
      .l = list(call, engine, label, chunk_order, stop_after, duckdb_threads),
      .f = ~ {
        # cli templates cannot start with a dot, so the arguments get names
        name_label_now <- ..3

        n_call_now <- ..1

        cli::cli_inform("Call {n_call_now}: {name_label_now}.")

        time_child_start <-
          base::Sys.time()

        res_child <-
          processx::run(
            command = path_rscript,
            args = c(
              path_child_script,
              ..2,
              base::normalizePath(path_run, winslash = "/"),
              ..3,
              ..4,
              base::as.character(..5),
              base::as.character(..6)
            ),
            wd = here::here(),
            timeout = 3600,
            error_on_status = FALSE
          )

        base::writeLines(
          text = c(
            purrr::chuck(res_child, "stdout"),
            purrr::chuck(res_child, "stderr")
          ),
          con = base::file.path(
            path_run, "logs",
            stringr::str_c("call_", ..1, "_", ..3, ".log")
          )
        )

        tibble::tibble(
          exit_status = purrr::chuck(res_child, "status"),
          timed_out = purrr::chuck(res_child, "timeout"),
          seconds_child = base::difftime(
            base::Sys.time(),
            time_child_start,
            units = "secs"
          ) |>
            base::as.numeric()
        )
      }
    )
  ) |>
  tidyr::unnest(result) |>
  dplyr::mutate(
    flag_as_expected = dplyr::if_else(
      flag_expect_stop,
      exit_status != 0L,
      exit_status == 0L
    )
  )

readr::write_csv(
  x = data_run_status,
  file = base::file.path(path_run, "run_status.csv")
)

assertthat::assert_that(
  base::all(data_run_status |> dplyr::pull(flag_as_expected)),
  msg = "An engine run ended differently than expected; see the logs."
)


#----------------------------------------------------------#
# 4. Fingerprints and comparison -----
#----------------------------------------------------------#

vec_labels <-
  data_runs |>
  dplyr::pull(label) |>
  base::unique()

data_fingerprints <-
  vec_labels |>
  purrr::map(
    .f = ~ {
      path_output <-
        base::file.path(path_run, stringr::str_c(.x, ".sqlite"))

      con_output <-
        DBI::dbConnect(
          RSQLite::SQLite(),
          path_output,
          flags = RSQLite::SQLITE_RO
        )

      vec_tables <-
        DBI::dbGetQuery(
          con_output,
          stringr::str_c(
            "SELECT name FROM sqlite_schema WHERE type = 'table' ",
            "AND name NOT LIKE 'sqlite_%' ORDER BY name"
          )
        ) |>
        dplyr::pull(name) |>
        base::setdiff(vec_bookkeeping_tables)

      text_quick_check <-
        DBI::dbGetQuery(con_output, "PRAGMA quick_check") |>
        purrr::chuck(1L) |>
        stringr::str_c(collapse = "; ")

      data_tables <-
        tibble::tibble(table_name = vec_tables) |>
        dplyr::mutate(
          result = purrr::map(
            .x = table_name,
            .f = ~ {
              vec_columns <-
                DBI::dbGetQuery(
                  con_output,
                  stringr::str_c("PRAGMA table_info(\"", .x, "\")")
                ) |>
                dplyr::pull(name)

              data_rows <-
                DBI::dbGetQuery(
                  con_output,
                  stringr::str_c(
                    "SELECT * FROM \"", .x, "\" ORDER BY ",
                    stringr::str_c("\"", vec_columns, "\"", collapse = ", ")
                  )
                )

              tibble::tibble(
                n_rows = base::nrow(data_rows),
                text_hash = data_rows |>
                  base::as.list() |>
                  base::unname() |>
                  rlang::hash(),
                text_types = data_rows |>
                  purrr::map_chr(.f = ~ base::class(.x) |> dplyr::first()) |>
                  stringr::str_c(collapse = " ")
              )
            }
          )
        ) |>
        tidyr::unnest(result) |>
        dplyr::mutate(
          label = .x,
          quick_check = text_quick_check,
          .before = 1L
        )

      DBI::dbDisconnect(con_output)

      data_tables
    }
  ) |>
  dplyr::bind_rows()

readr::write_csv(
  x = data_fingerprints,
  file = base::file.path(path_run, "fingerprints.csv")
)

name_reference <-
  "r_memory_rep1"

# Every table against the reference; differing tables get the rows found
#   only in one of the two outputs
data_comparison <-
  data_fingerprints |>
  dplyr::left_join(
    data_fingerprints |>
      dplyr::filter(label == name_reference) |>
      dplyr::select(
        table_name,
        n_rows_reference = n_rows,
        text_hash_reference = text_hash
      ),
    by = "table_name"
  ) |>
  dplyr::mutate(flag_same = text_hash == text_hash_reference) |>
  dplyr::mutate(
    result = purrr::pmap(
      .l = list(label, table_name, flag_same),
      .f = ~ {
        if (
          base::isTRUE(..3)
        ) {
          tibble::tibble(n_only_run = 0, n_only_reference = 0)
        } else {
          con_compare <-
            DBI::dbConnect(RSQLite::SQLite(), ":memory:")

          DBI::dbExecute(
            con_compare,
            "ATTACH DATABASE ? AS run",
            params = list(
              stringr::str_c(
                "file:",
                base::normalizePath(
                  base::file.path(path_run, stringr::str_c(..1, ".sqlite")),
                  winslash = "/"
                ),
                "?mode=ro"
              )
            )
          )

          DBI::dbExecute(
            con_compare,
            "ATTACH DATABASE ? AS ref",
            params = list(
              stringr::str_c(
                "file:",
                base::normalizePath(
                  base::file.path(
                    path_run, stringr::str_c(name_reference, ".sqlite")
                  ),
                  winslash = "/"
                ),
                "?mode=ro"
              )
            )
          )

          data_difference <-
            tibble::tibble(
              n_only_run = DBI::dbGetQuery(
                con_compare,
                stringr::str_c(
                  "SELECT count(*) AS n FROM (SELECT * FROM run.\"", ..2,
                  "\" EXCEPT SELECT * FROM ref.\"", ..2, "\")"
                )
              ) |>
                dplyr::pull(n),
              n_only_reference = DBI::dbGetQuery(
                con_compare,
                stringr::str_c(
                  "SELECT count(*) AS n FROM (SELECT * FROM ref.\"", ..2,
                  "\" EXCEPT SELECT * FROM run.\"", ..2, "\")"
                )
              ) |>
                dplyr::pull(n)
            )

          DBI::dbDisconnect(con_compare)

          data_difference
        }
      }
    )
  ) |>
  tidyr::unnest(result)

readr::write_csv(
  x = data_comparison,
  file = base::file.path(path_run, "comparison.csv")
)


#----------------------------------------------------------#
# 5. Summaries and the run record -----
#----------------------------------------------------------#

data_steps <-
  base::list.files(path_run, pattern = "_steps[.]csv$", full.names = TRUE) |>
  purrr::map(
    .f = ~ readr::read_csv(.x, show_col_types = FALSE, num_threads = 1L)
  ) |>
  dplyr::bind_rows()

data_memory <-
  base::list.files(path_run, pattern = "_memory[.]csv$", full.names = TRUE) |>
  purrr::map(
    .f = ~ readr::read_csv(.x, show_col_types = FALSE, num_threads = 1L)
  ) |>
  dplyr::bind_rows()

readr::write_csv(
  x = data_steps,
  file = base::file.path(path_run, "steps.csv")
)

readr::write_csv(
  x = data_memory,
  file = base::file.path(path_run, "memory.csv")
)

data_engine_summary <-
  data_steps |>
  # Rows without seconds hold sizes, not steps
  dplyr::filter(!base::is.na(seconds)) |>
  dplyr::summarise(
    seconds_build = base::sum(seconds),
    .by = c(engine, label, session)
  ) |>
  dplyr::left_join(
    data_memory |>
      dplyr::select(label, session, peak_wset_mb, file_mb),
    by = c("label", "session")
  )

readr::write_csv(
  x = data_engine_summary,
  file = base::file.path(path_run, "engine_summary.csv")
)

flag_subset_unchanged <-
  base::file.size(path_subset) == size_subset_before &&
  base::file.mtime(path_subset) == mtime_subset_before &&
  base::identical(
    base::readBin(con = path_subset, what = "raw", n = 100L),
    vec_subset_header_before
  )

readr::write_csv(
  x = tibble::tibble(
    script = "17_benchmark_build_engines.R",
    smoke = flag_smoke,
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    n_repetitions = n_repetitions,
    chunk_size = purrr::chuck(list_settings_engines, "chunk_size"),
    duckdb_threads = purrr::chuck(list_settings_engines, "duckdb_threads"),
    duckdb_memory_limit = purrr::chuck(
      list_settings_engines, "duckdb_memory_limit"
    ),
    n_cores = parallel::detectCores(),
    r_version = base::as.character(base::getRversion()),
    rsqlite_version = base::as.character(
      utils::packageVersion("RSQLite")
    ),
    dplyr_version = base::as.character(utils::packageVersion("dplyr")),
    geosphere_version = base::as.character(
      utils::packageVersion("geosphere")
    ),
    subset_unchanged = flag_subset_unchanged,
    all_tables_same_as_reference = base::all(
      data_comparison |> dplyr::pull(flag_same)
    )
  ),
  file = base::file.path(path_run, "run_info.csv")
)

assertthat::assert_that(
  base::isTRUE(flag_subset_unchanged),
  msg = "The subset file changed during the run."
)

cli::cli_inform(
  c(
    "v" = "Benchmarked the build engines.",
    "i" = "Results in {.path {path_run}}."
  )
)
