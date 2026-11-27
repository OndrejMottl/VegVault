#----------------------------------------------------------#
#
#
#                       VegVault
#
#             Full read-only scans of v1.0.0
#     - object sizes (dbstat), exact counts, distributions
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Measure the on-disk size of every table and index of v1.0.0 with the
#   dbstat virtual table, and compute exact row counts and the
#   distributions that the schema decisions depend on: sample composition,
#   links per sample and per gridpoint, stored distance types, duplicate
#   names, distinct (long, lat, age) tuples, samples without values or
#   links, and the gridpoint ages and cells.
# These are full scans of a file of about 110 GB. They run only with the
#   maintainer's approval and never alongside another heavy job.
# v1.0.0 is opened read-only: by the sqlite3 command-line tool with
#   `-readonly` and `PRAGMA query_only` for dbstat, and through RSQLite
#   with `SQLITE_RO` for everything else. Its size, modification time, and
#   header are compared before and after. The path is passed to the
#   command-line tool only inside `processx`, and any error text has the
#   path removed before it is shown.
# Each result is saved as soon as it is computed; a rerun skips results
#   that already exist, so an interrupted run resumes where it stopped.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (resolves `path_to_vegvault` from the secrets file)
source(
  here::here("R/00_Config_file.R")
)

# Optional checks; see the approval request for their measured cost
flag_run_foreign_key_check <- TRUE
flag_run_quick_check <- FALSE
flag_run_integrity_check <- FALSE

path_research <-
  here::here("Data", "Temp", "Database_research")

path_output <-
  base::file.path(path_research, "V1_full_scans")

path_sqlite_exe <-
  base::file.path(
    path_research,
    "Tools",
    "sqlite-tools-3540100",
    "sqlite3.exe"
  )

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

# Connection page cache in KiB (negative value); 4 GiB of the 64 GiB RAM
value_cache_size_kib <- -4194304

base::dir.create(
  path = path_output,
  recursive = TRUE,
  showWarnings = FALSE
)

assertthat::assert_that(
  base::file.exists(path_to_vegvault),
  msg = "The database file named in the secrets file does not exist."
)

assertthat::assert_that(
  base::file.exists(path_sqlite_exe),
  msg = "The sqlite3 command-line tool is missing from Data/Temp."
)

# Every spelling of the private path that could appear in tool messages
vec_path_spellings <-
  c(
    path_to_vegvault,
    base::normalizePath(path_to_vegvault, winslash = "\\"),
    base::normalizePath(path_to_vegvault, winslash = "/")
  ) |>
  base::unique()

time_run_start <-
  base::Sys.time()


#----------------------------------------------------------#
# 1. Record the file state before reading -----
#----------------------------------------------------------#

vec_header_raw_before <-
  base::readBin(
    con = path_to_vegvault,
    what = "raw",
    n = 100L
  )

size_bytes_before <-
  base::file.size(path_to_vegvault)

mtime_before <-
  base::file.mtime(path_to_vegvault)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only opened when it uses a rollback journal
if (
  base::as.integer(vec_header_raw_before[19L]) != 1L ||
    base::as.integer(vec_header_raw_before[20L]) != 1L ||
    base::any(
      base::file.exists(
        stringr::str_c(path_to_vegvault, vec_sibling_suffix)
      )
    )
) {
  cli::cli_abort(
    c(
      "The database is in WAL mode or has a journal file next to it.",
      "i" = "It was not opened, to avoid creating files next to it."
    )
  )
}


#----------------------------------------------------------#
# 2. Object sizes with dbstat -----
#----------------------------------------------------------#

path_dbstat <-
  base::file.path(path_output, "dbstat_by_object.csv")

if (
  base::isFALSE(base::file.exists(path_dbstat))
) {
  time_dbstat_start <-
    base::Sys.time()

  res_dbstat <-
    processx::run(
      command = path_sqlite_exe,
      args = c(
        "-readonly",
        "-csv",
        "-header",
        path_to_vegvault,
        stringr::str_c(
          "PRAGMA query_only = 1; ",
          "SELECT name, pageno AS n_pages, pgsize AS bytes, ",
          "unused AS unused_bytes, payload AS payload_bytes, ",
          "ncell AS n_cells, mx_payload AS max_payload_bytes ",
          "FROM dbstat WHERE aggregate = TRUE ORDER BY bytes DESC;"
        )
      ),
      timeout = 4 * 3600,
      error_on_status = FALSE
    )

  if (
    purrr::chuck(res_dbstat, "status") != 0L
  ) {
    text_error_redacted <-
      purrr::reduce(
        .x = vec_path_spellings,
        .f = ~ stringr::str_replace_all(
          string = .x,
          pattern = stringr::fixed(.y),
          replacement = "<v1 file>"
        ),
        .init = purrr::chuck(res_dbstat, "stderr")
      )

    cli::cli_abort(
      c(
        "dbstat failed.",
        "x" = "{text_error_redacted}"
      )
    )
  }

  base::writeLines(
    text = purrr::chuck(res_dbstat, "stdout"),
    con = path_dbstat,
    sep = ""
  )

  readr::write_csv(
    x = tibble::tibble(
      result_name = "dbstat_by_object",
      seconds = base::difftime(
        base::Sys.time(),
        time_dbstat_start,
        units = "secs"
      ) |>
        base::as.numeric()
    ),
    file = base::file.path(path_output, "seconds_dbstat_by_object.csv")
  )
}


#----------------------------------------------------------#
# 3. Exact counts and distributions -----
#----------------------------------------------------------#

# Ordered from cheap to expensive, by the rates measured on the subset
data_queries <-
  tibble::tribble(
    ~result_name, ~flag_run, ~sql,
    "dataset_composition", TRUE, stringr::str_c(
      "SELECT dataset_type_id, data_source_type_id, ",
      "count(*) AS n_datasets, ",
      "sum(coord_long IS NULL OR coord_lat IS NULL) AS n_coord_missing ",
      "FROM Datasets GROUP BY 1, 2"
    ),
    "gridpoint_cells", TRUE, stringr::str_c(
      "SELECT coord_long, coord_lat FROM Datasets ",
      "WHERE dataset_type_id = 4"
    ),
    "duplicate_dataset_names", TRUE, stringr::str_c(
      "SELECT count(*) AS n_names_duplicated, ",
      "coalesce(sum(n), 0) AS n_rows FROM (SELECT dataset_name, ",
      "count(*) AS n FROM Datasets GROUP BY dataset_name ",
      "HAVING count(*) > 1)"
    ),
    "abiotic_values_per_variable", TRUE, stringr::str_c(
      "SELECT abiotic_variable_id, typeof(abiotic_value) AS value_type, ",
      "count(*) AS n_values FROM AbioticData GROUP BY 1, 2"
    ),
    "duplicate_sample_names", TRUE, stringr::str_c(
      "SELECT count(*) AS n_names_duplicated, ",
      "coalesce(sum(n), 0) AS n_rows, ",
      "coalesce(sum(sample_name IS NULL), 0) AS n_name_missing ",
      "FROM (SELECT sample_name, count(*) AS n FROM Samples ",
      "GROUP BY sample_name HAVING count(*) > 1)"
    ),
    "sample_composition", TRUE, stringr::str_c(
      "SELECT d.dataset_type_id, d.data_source_type_id, ",
      "count(*) AS n_samples, sum(s.age IS NULL) AS n_age_missing, ",
      "min(s.age) AS age_min, max(s.age) AS age_max ",
      "FROM DatasetSample ds ",
      "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
      "JOIN Samples s ON s.sample_id = ds.sample_id GROUP BY 1, 2"
    ),
    "gridpoint_ages", TRUE, stringr::str_c(
      "SELECT s.age, count(*) AS n_samples FROM Datasets d ",
      "JOIN DatasetSample ds ON ds.dataset_id = d.dataset_id ",
      "JOIN Samples s ON s.sample_id = ds.sample_id ",
      "WHERE d.dataset_type_id = 4 GROUP BY s.age"
    ),
    "tuples_per_source", TRUE, stringr::str_c(
      "SELECT dataset_type_id, data_source_type_id, ",
      "count(*) AS n_tuples, sum(n) AS n_samples FROM (",
      "SELECT d.dataset_type_id, d.data_source_type_id, d.coord_long, ",
      "d.coord_lat, s.age, count(*) AS n FROM DatasetSample ds ",
      "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
      "JOIN Samples s ON s.sample_id = ds.sample_id ",
      "WHERE d.dataset_type_id != 4 GROUP BY 1, 2, 3, 4, 5) GROUP BY 1, 2"
    ),
    "tuples_all_sources", TRUE, stringr::str_c(
      "SELECT count(*) AS n_tuples FROM (",
      "SELECT DISTINCT d.coord_long, d.coord_lat, s.age ",
      "FROM DatasetSample ds ",
      "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
      "JOIN Samples s ON s.sample_id = ds.sample_id ",
      "WHERE d.dataset_type_id != 4)"
    ),
    "trait_samples_without_value", TRUE, stringr::str_c(
      "SELECT d.data_source_type_id, count(*) AS n_samples, ",
      "sum(NOT EXISTS (SELECT 1 FROM TraitsValue tv ",
      "WHERE tv.sample_id = ds.sample_id)) AS n_without_value ",
      "FROM DatasetSample ds ",
      "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
      "WHERE d.dataset_type_id = 3 GROUP BY 1"
    ),
    "trait_values_per_sample", TRUE, stringr::str_c(
      "SELECT count(*) AS n_values, count(DISTINCT sample_id) AS ",
      "n_samples, sum(sample_id IS NULL) AS n_sample_missing ",
      "FROM TraitsValue"
    ),
    "samples_without_links", TRUE, stringr::str_c(
      "SELECT d.dataset_type_id, d.data_source_type_id, ",
      "count(*) AS n_samples, ",
      "sum(d.coord_long IS NULL OR d.coord_lat IS NULL) AS ",
      "n_coord_missing, sum(s.age IS NULL) AS n_age_missing, ",
      "min(d.coord_lat) AS lat_min, max(d.coord_lat) AS lat_max, ",
      "sum(abs(d.coord_lat) > 60) AS n_lat_above_60 ",
      "FROM DatasetSample ds ",
      "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
      "JOIN Samples s ON s.sample_id = ds.sample_id ",
      "WHERE d.dataset_type_id != 4 AND NOT EXISTS (SELECT 1 ",
      "FROM AbioticDataReference a WHERE a.sample_id = ds.sample_id) ",
      "GROUP BY 1, 2"
    ),
    "gridpoint_samples_without_values_or_links", TRUE, stringr::str_c(
      "SELECT count(*) AS n_samples, ",
      "sum(NOT EXISTS (SELECT 1 FROM AbioticData ad ",
      "WHERE ad.sample_id = ds.sample_id)) AS n_without_values, ",
      "sum(NOT EXISTS (SELECT 1 FROM AbioticDataReference a ",
      "WHERE a.sample_ref_id = ds.sample_id)) AS n_not_linked ",
      "FROM DatasetSample ds ",
      "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
      "WHERE d.dataset_type_id = 4"
    ),
    "links_per_sample", TRUE, stringr::str_c(
      "SELECT n_links, count(*) AS n_samples FROM (",
      "SELECT sample_id, count(*) AS n_links ",
      "FROM AbioticDataReference GROUP BY sample_id) GROUP BY n_links"
    ),
    "links_per_gridpoint", TRUE, stringr::str_c(
      "SELECT n_links, count(*) AS n_gridpoint_samples FROM (",
      "SELECT sample_ref_id, count(*) AS n_links ",
      "FROM AbioticDataReference GROUP BY sample_ref_id) GROUP BY n_links"
    ),
    "link_distance_types", TRUE, stringr::str_c(
      "SELECT typeof(distance_in_km) AS type_km, ",
      "typeof(distance_in_years) AS type_years, count(*) AS n_links, ",
      "min(distance_in_km) AS km_min, max(distance_in_km) AS km_max, ",
      "min(distance_in_years) AS years_min, ",
      "max(distance_in_years) AS years_max, ",
      "sum(sample_id IS NULL OR sample_ref_id IS NULL) AS n_key_missing ",
      "FROM AbioticDataReference GROUP BY 1, 2"
    ),
    "foreign_key_check", flag_run_foreign_key_check, stringr::str_c(
      "SELECT \"table\" AS child_table, parent AS parent_table, ",
      "count(*) AS n_violations FROM pragma_foreign_key_check ",
      "GROUP BY 1, 2"
    ),
    "quick_check", flag_run_quick_check, "PRAGMA quick_check",
    "integrity_check", flag_run_integrity_check, "PRAGMA integrity_check"
  ) |>
  dplyr::mutate(
    path_result = base::file.path(
      path_output,
      stringr::str_c(result_name, ".csv")
    ),
    flag_done = base::file.exists(path_result)
  )

data_queries_to_run <-
  data_queries |>
  dplyr::filter(flag_run, !flag_done)

con_v1 <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_to_vegvault,
    flags = RSQLite::SQLITE_RO,
    bigint = "numeric"
  )

tryCatch(
  expr = {
    DBI::dbExecute(
      conn = con_v1,
      statement = stringr::str_c(
        "PRAGMA cache_size = ", value_cache_size_kib
      )
    )

    purrr::pwalk(
      .l = list(
        data_queries_to_run |>
          dplyr::pull(result_name),
        data_queries_to_run |>
          dplyr::pull(sql),
        data_queries_to_run |>
          dplyr::pull(path_result)
      ),
      .f = ~ {
        # cli templates cannot start with a dot, so `..1` gets a name
        name_query <- ..1

        cli::cli_inform("Running {name_query}.")

        time_query_start <-
          base::Sys.time()

        data_result <-
          DBI::dbGetQuery(conn = con_v1, statement = ..2) |>
          tibble::as_tibble()

        readr::write_csv(
          x = data_result,
          file = ..3
        )

        readr::write_csv(
          x = tibble::tibble(
            result_name = ..1,
            seconds = base::difftime(
              base::Sys.time(),
              time_query_start,
              units = "secs"
            ) |>
              base::as.numeric()
          ),
          file = base::file.path(
            path_output,
            stringr::str_c("seconds_", ..1, ".csv")
          )
        )
      }
    )
  },
  finally = DBI::dbDisconnect(con_v1)
)


#----------------------------------------------------------#
# 4. Check that the file was not changed -----
#----------------------------------------------------------#

vec_header_raw_after <-
  base::readBin(
    con = path_to_vegvault,
    what = "raw",
    n = 100L
  )

flag_file_unchanged <-
  base::isTRUE(
    base::file.size(path_to_vegvault) == size_bytes_before &&
      base::file.mtime(path_to_vegvault) == mtime_before &&
      base::identical(vec_header_raw_before, vec_header_raw_after) &&
      !base::any(
        base::file.exists(
          stringr::str_c(path_to_vegvault, vec_sibling_suffix)
        )
      )
  )

readr::write_csv(
  x = tibble::tibble(
    script = "06_scan_v1_full.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    n_results_run = base::nrow(data_queries_to_run),
    connection_flags = "sqlite3 -readonly + query_only; RSQLite SQLITE_RO",
    file_unchanged = flag_file_unchanged
  ),
  file = base::file.path(
    path_output,
    stringr::str_c(
      "run_info_",
      base::format(time_run_start, "%Y-%m-%d_%H%M%S"),
      ".csv"
    )
  )
)

if (
  base::isFALSE(flag_file_unchanged)
) {
  cli::cli_abort(
    "The database file differs after the read-only session."
  )
}

cli::cli_inform(
  c(
    "v" = "Read-only scans finished; the file is unchanged.",
    "i" = "Results saved to {.path {path_output}}."
  )
)
