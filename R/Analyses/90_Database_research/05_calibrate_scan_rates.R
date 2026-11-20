#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Calibrate full-scan rates on the regional subset
#            - to estimate the cost of full v1.0.0 scans
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Time the full scans planned for v1.0.0 (dbstat, row counts, distance
#   types, duplicate names, integrity checks) on the disposable regional
#   subset with the official sqlite3 command-line tool, which includes the
#   dbstat virtual table. The measured rates (pages or rows per second)
#   are scaled to the v1.0.0 page and row counts recorded by
#   `01_inspect_v1_metadata.R`, to estimate how long each full v1.0.0 scan
#   would take. The subset file was just written, so it is read from the
#   operating-system cache: the rates are CPU-bound and the estimates are
#   lower bounds for v1.0.0, which is larger than the memory of the
#   machine. v1.0.0 itself is not opened.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration
source(
  here::here("R/00_Config_file.R")
)

list_settings_subset <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  ) |>
  purrr::chuck("subset")

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

path_sqlite_exe <-
  base::file.path(
    path_research,
    "Tools",
    "sqlite-tools-3540100",
    "sqlite3.exe"
  )

path_v1_metadata <-
  base::file.path(path_research, "V1_metadata")

path_output <-
  base::file.path(path_research, "Scan_calibration")

base::dir.create(
  path = path_output,
  recursive = TRUE,
  showWarnings = FALSE
)

n_repetitions <- 3L

seconds_timeout <- 3600

assertthat::assert_that(
  base::file.exists(path_subset),
  msg = "The regional subset does not exist; run 04_extract_v1_subset.R."
)

assertthat::assert_that(
  base::file.exists(path_sqlite_exe),
  msg = "The sqlite3 command-line tool is missing from Data/Temp."
)

# Each scan, the table whose size scales it, and the unit of its rate
data_scans <-
  tibble::tribble(
    ~scan_name, ~scale_table, ~scale_unit, ~sql,
    "dbstat_by_object", "<file>", "pages", stringr::str_c(
      "SELECT name, count(*) AS n_pages, sum(pgsize) AS bytes, ",
      "sum(unused) AS unused_bytes, sum(payload) AS payload_bytes, ",
      "sum(ncell) AS n_cells FROM dbstat GROUP BY name ",
      "ORDER BY bytes DESC;"
    ),
    "dbstat_aggregate", "<file>", "pages", stringr::str_c(
      "SELECT name, pageno AS n_pages, pgsize AS bytes, ",
      "unused AS unused_bytes, payload AS payload_bytes, ",
      "ncell AS n_cells FROM dbstat WHERE aggregate = TRUE ",
      "ORDER BY bytes DESC;"
    ),
    "count_links", "AbioticDataReference", "rows", stringr::str_c(
      "SELECT count(*) AS n FROM AbioticDataReference;"
    ),
    "link_distance_types", "AbioticDataReference", "rows", stringr::str_c(
      "SELECT typeof(distance_in_km) AS type_km, ",
      "typeof(distance_in_years) AS type_years, count(*) AS n, ",
      "min(distance_in_km) AS km_min, max(distance_in_km) AS km_max, ",
      "min(distance_in_years) AS years_min, ",
      "max(distance_in_years) AS years_max ",
      "FROM AbioticDataReference GROUP BY 1, 2;"
    ),
    "links_per_sample", "AbioticDataReference", "rows", stringr::str_c(
      "SELECT count(*) AS n_samples, sum(n) AS n_links, ",
      "max(n) AS links_max FROM (SELECT sample_id, count(*) AS n ",
      "FROM AbioticDataReference GROUP BY sample_id);"
    ),
    "duplicate_sample_names", "Samples", "rows", stringr::str_c(
      "SELECT count(*) AS n_names_duplicated, ",
      "coalesce(sum(n), 0) AS n_rows FROM (SELECT sample_name, ",
      "count(*) AS n FROM Samples GROUP BY sample_name ",
      "HAVING count(*) > 1);"
    ),
    "duplicate_dataset_names", "Datasets", "rows", stringr::str_c(
      "SELECT count(*) AS n_names_duplicated, ",
      "coalesce(sum(n), 0) AS n_rows FROM (SELECT dataset_name, ",
      "count(*) AS n FROM Datasets GROUP BY dataset_name ",
      "HAVING count(*) > 1);"
    ),
    "quick_check", "<file>", "pages", "PRAGMA quick_check;",
    "integrity_check", "<file>", "pages", "PRAGMA integrity_check;",
    "foreign_key_check", "<file>", "pages", stringr::str_c(
      "SELECT count(*) AS n_violations FROM pragma_foreign_key_check;"
    )
  )


#----------------------------------------------------------#
# 1. Time each scan on the subset -----
#----------------------------------------------------------#

data_scan_runs <-
  data_scans |>
  dplyr::select(scan_name, sql) |>
  tidyr::expand_grid(repetition = base::seq_len(n_repetitions)) |>
  dplyr::mutate(
    result = purrr::map(
      .x = sql,
      .f = ~ {
        time_scan_start <-
          base::Sys.time()

        res_process <-
          processx::run(
            command = path_sqlite_exe,
            args = c("-readonly", "-csv", "-header", path_subset, .x),
            timeout = seconds_timeout,
            error_on_status = TRUE
          )

        tibble::tibble(
          seconds = base::difftime(
            base::Sys.time(),
            time_scan_start,
            units = "secs"
          ) |>
            base::as.numeric(),
          stdout = purrr::chuck(res_process, "stdout")
        )
      }
    )
  ) |>
  tidyr::unnest(cols = result)


#----------------------------------------------------------#
# 2. Scale the rates to v1.0.0 -----
#----------------------------------------------------------#

data_v1_rows <-
  readr::read_csv(
    file = base::file.path(path_v1_metadata, "rowid_bounds.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::select(scale_table = table_name, n_units_v1 = max_rowid)

n_pages_v1 <-
  readr::read_csv(
    file = base::file.path(path_v1_metadata, "pragmas.csv"),
    show_col_types = FALSE
  ) |>
  dplyr::filter(pragma == "page_count") |>
  dplyr::pull(value) |>
  base::as.numeric()

con_subset <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_subset,
    flags = RSQLite::SQLITE_RO
  )

tryCatch(
  expr = {
    data_subset_rows <-
      c("AbioticDataReference", "Samples", "Datasets") |>
      purrr::map(
        .f = ~ tibble::tibble(
          scale_table = .x,
          n_units_subset = DBI::dbGetQuery(
            conn = con_subset,
            statement = stringr::str_c("SELECT count(*) AS n FROM ", .x)
          ) |>
            dplyr::pull(n)
        )
      ) |>
      dplyr::bind_rows()

    n_pages_subset <-
      DBI::dbGetQuery(
        conn = con_subset,
        statement = "PRAGMA page_count"
      ) |>
      dplyr::pull(page_count)
  },
  finally = DBI::dbDisconnect(con_subset)
)

data_subset_units <-
  dplyr::bind_rows(
    data_subset_rows,
    tibble::tibble(scale_table = "<file>", n_units_subset = n_pages_subset)
  )

table_scan_rates <-
  data_scan_runs |>
  dplyr::summarise(
    seconds_min = base::min(seconds),
    seconds_median = stats::median(seconds),
    seconds_max = base::max(seconds),
    .by = scan_name
  ) |>
  dplyr::left_join(
    data_scans |>
      dplyr::select(scan_name, scale_table, scale_unit),
    by = dplyr::join_by(scan_name),
    relationship = "one-to-one"
  ) |>
  dplyr::left_join(
    data_subset_units,
    by = dplyr::join_by(scale_table),
    relationship = "many-to-one"
  ) |>
  dplyr::left_join(
    dplyr::bind_rows(
      data_v1_rows,
      tibble::tibble(scale_table = "<file>", n_units_v1 = n_pages_v1)
    ),
    by = dplyr::join_by(scale_table),
    relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    units_per_second = n_units_subset / seconds_median,
    # Linear in pages or rows; warm cache, so a lower bound for v1.0.0
    v1_seconds_estimated = n_units_v1 / units_per_second,
    v1_minutes_estimated = v1_seconds_estimated / 60
  )


#----------------------------------------------------------#
# 3. Save results -----
#----------------------------------------------------------#

data_scan_outputs <-
  data_scan_runs |>
  dplyr::filter(repetition == n_repetitions) |>
  dplyr::select(scan_name, stdout)

purrr::walk2(
  .x = data_scan_outputs |>
    dplyr::pull(scan_name),
  .y = data_scan_outputs |>
    dplyr::pull(stdout),
  .f = ~ base::writeLines(
    text = .y,
    con = base::file.path(
      path_output,
      stringr::str_c("subset_", .x, ".csv")
    ),
    sep = ""
  )
)

data_run_info <-
  tibble::tibble(
    script = "05_calibrate_scan_rates.R",
    sqlite_cli_version = processx::run(
      command = path_sqlite_exe,
      args = "-version"
    ) |>
      purrr::chuck("stdout") |>
      stringr::str_squish(),
    subset_size_bytes = base::file.size(path_subset),
    n_repetitions = n_repetitions,
    cache_state = "warm (subset written shortly before)"
  )

list_outputs <-
  list(
    run_info = data_run_info,
    scan_runs = data_scan_runs |>
      dplyr::select(scan_name, repetition, seconds),
    scan_rates = table_scan_rates
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
    "v" = "Scan rates measured on the subset.",
    "i" = "Results saved to {.path {path_output}}."
  )
)
