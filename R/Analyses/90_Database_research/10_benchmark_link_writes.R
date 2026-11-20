#----------------------------------------------------------#
#
#
#                       VegVault
#
#       Benchmark the v1 link query, table reads, and writes
#             - on the regional subset and disposable files
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Time, at subset scale, the database operations of the v1 gridpoint stage
#   that 08_profile_v1_gridpoints.R cannot separate cleanly:
#   1. The large `IN` query of add_gridpoints_with_links() (links of the
#      existing gridpoint samples), with 1, 10, and 100 % of the gridpoint
#      sample ids of the subset.
#   2. The whole-table reads of the v1 writers (Samples, Datasets,
#      DatasetSample, AbioticData), as rows per second, and the duplicate
#      test of add_to_db() on the tables it reads whole.
#   3. Writing the 48.5 M links of the subset in 12 batches (the number of
#      batches of the full subset box) in three ways:
#      - `v1_copy_to`: dplyr::copy_to() with its defaults, as add_to_db()
#        does, into a table that already has the two v1 indexes; the
#        defaults include `analyze = TRUE`, which runs `ANALYZE` on the
#        table after every write
#      - `copy_to_no_analyze`: the same with `analyze = FALSE`
#      - `append_then_index`: DBI::dbAppendTable() into a table without
#        indexes, the two indexes created at the end, then one `ANALYZE`
#        of the full table
# The subset is opened read-only. Writes go to new files in the run folder,
#   which are deleted after their sizes are recorded. Each run writes a new
#   folder `run_<timestamp>` under `Profiling/writes` and never overwrites.
#   v1.0.0 is not opened.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (also sources the v1 functions)
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

time_run_start <-
  base::Sys.time()

path_run <-
  base::file.path(
    path_research,
    "Profiling",
    "writes",
    stringr::str_c("run_", base::format(time_run_start, "%Y%m%d_%H%M%S"))
  )

n_repetitions <- 3L

n_write_batches <- 12L

vec_in_query_shares <- c(0.01, 0.1, 1)

# Each read as written in the v1 function named
data_reads <-
  tibble::tribble(
    ~read_name, ~table_name, ~v1_function,
    "samples_all_columns", "Samples", "add_to_db",
    "samples_distinct_names", "Samples", "add_samples_id",
    "samples_id_name", "Samples", "add_samples_id, add_abiotic_data_ref",
    "datasets_all_columns", "Datasets", "add_to_db",
    "dataset_sample_ids", "DatasetSample", "add_dataset_sample",
    "abiotic_data_ids", "AbioticData", "add_sample_abiotic_value"
  )

assertthat::assert_that(
  base::file.exists(path_subset),
  msg = "The regional subset does not exist; run 04_extract_v1_subset.R."
)

assertthat::assert_that(
  base::isFALSE(base::dir.exists(path_run)),
  msg = "The run folder exists already."
)

base::dir.create(path = path_run, recursive = TRUE)


#----------------------------------------------------------#
# 1. Reads on the subset -----
#----------------------------------------------------------#

con_subset <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_subset,
    flags = RSQLite::SQLITE_RO
  )

tryCatch(
  expr = {
    #--------------------------------------------------#
    ## 1.1. The large IN query -----
    #--------------------------------------------------#

    vec_gridpoint_sample_id <-
      DBI::dbGetQuery(
        conn = con_subset,
        statement = stringr::str_c(
          "SELECT ds.sample_id FROM DatasetSample ds ",
          "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
          "WHERE d.dataset_type_id = 4 ORDER BY ds.sample_id"
        )
      ) |>
      dplyr::pull(sample_id)

    data_in_query_runs <-
      tidyr::expand_grid(
        share = vec_in_query_shares,
        repetition = base::seq_len(n_repetitions)
      ) |>
      dplyr::mutate(
        result = purrr::map(
          .x = share,
          .f = ~ {
            vec_gridpoints_sample_id <-
              utils::head(
                x = vec_gridpoint_sample_id,
                n = base::round(.x * base::length(vec_gridpoint_sample_id))
              )

            time_query_start <-
              base::Sys.time()

            # The query of add_gridpoints_with_links(), unchanged
            vec_relevant_vegetation_sample_names <-
              dplyr::tbl(con_subset, "AbioticDataReference") |>
              dplyr::select("sample_id", "sample_ref_id") |>
              dplyr::filter(
                sample_ref_id %in% vec_gridpoints_sample_id
              ) |>
              dplyr::distinct(sample_id) |>
              dplyr::left_join(
                dplyr::tbl(con_subset, "Samples") |>
                  dplyr::select("sample_id", "sample_name"),
                by = dplyr::join_by("sample_id")
              ) |>
              dplyr::collect() |>
              purrr::chuck("sample_name")

            tibble::tibble(
              n_ids = base::length(vec_gridpoints_sample_id),
              n_names = base::length(vec_relevant_vegetation_sample_names),
              seconds = base::difftime(
                base::Sys.time(),
                time_query_start,
                units = "secs"
              ) |>
                base::as.numeric()
            )
          }
        )
      ) |>
      tidyr::unnest(cols = result)

    #--------------------------------------------------#
    ## 1.2. Whole-table reads of the v1 writers -----
    #--------------------------------------------------#

    list_read_queries <-
      list(
        samples_all_columns = dplyr::tbl(con_subset, "Samples"),
        samples_distinct_names = dplyr::tbl(con_subset, "Samples") |>
          dplyr::distinct(sample_name),
        samples_id_name = dplyr::tbl(con_subset, "Samples") |>
          dplyr::select(sample_id, sample_name),
        datasets_all_columns = dplyr::tbl(con_subset, "Datasets"),
        dataset_sample_ids = dplyr::tbl(con_subset, "DatasetSample") |>
          dplyr::select(dataset_id, sample_id),
        abiotic_data_ids = dplyr::tbl(con_subset, "AbioticData") |>
          dplyr::select(sample_id, abiotic_variable_id)
      )

    data_read_runs <-
      data_reads |>
      tidyr::expand_grid(repetition = base::seq_len(n_repetitions)) |>
      dplyr::mutate(
        result = purrr::map(
          .x = read_name,
          .f = ~ {
            time_read_start <-
              base::Sys.time()

            data_read <-
              purrr::chuck(list_read_queries, .x) |>
              dplyr::collect()

            time_read_end <-
              base::Sys.time()

            # The duplicate test of add_to_db(), for the tables it reads
            #   whole
            seconds_unique_test <-
              if (
                stringr::str_ends(.x, "all_columns")
              ) {
                base::system.time(
                  test_unique_row_in_table(data_read)
                )[["elapsed"]]
              } else {
                NA_real_
              }

            tibble::tibble(
              n_rows = base::nrow(data_read),
              seconds_read = base::difftime(
                time_read_end,
                time_read_start,
                units = "secs"
              ) |>
                base::as.numeric(),
              seconds_unique_test = seconds_unique_test
            )
          }
        )
      ) |>
      tidyr::unnest(cols = result)

    #--------------------------------------------------#
    ## 1.3. The links to write -----
    #--------------------------------------------------#

    time_links_read_start <-
      base::Sys.time()

    data_links <-
      DBI::dbGetQuery(
        conn = con_subset,
        statement = stringr::str_c(
          "SELECT sample_id, sample_ref_id, distance_in_km, ",
          "distance_in_years FROM AbioticDataReference ORDER BY rowid"
        )
      ) |>
      tibble::as_tibble()

    seconds_links_read <-
      base::difftime(
        base::Sys.time(),
        time_links_read_start,
        units = "secs"
      ) |>
      base::as.numeric()
  },
  finally = DBI::dbDisconnect(con_subset)
)


#----------------------------------------------------------#
# 2. Writes of the links -----
#----------------------------------------------------------#

n_links <-
  base::nrow(data_links)

n_rows_per_batch <-
  base::ceiling(n_links / n_write_batches)

# Row ranges of the write batches
data_write_batches <-
  tibble::tibble(write_batch = base::seq_len(n_write_batches)) |>
  dplyr::mutate(
    row_from = (write_batch - 1L) * n_rows_per_batch + 1L,
    row_to = base::pmin(write_batch * n_rows_per_batch, n_links)
  )

# The v1 table and its indexes, as in Data/SQL/make_tables.sql
sql_create_links <-
  stringr::str_c(
    "CREATE TABLE \"AbioticDataReference\"(",
    "\"sample_id\" INTEGER, \"sample_ref_id\" INTEGER, ",
    "\"distance_in_km\" INTEGER, \"distance_in_years\" INTEGER)"
  )

vec_sql_create_indexes <-
  c(
    stringr::str_c(
      "CREATE INDEX idx_abioticdatareference_sample_id ",
      "ON AbioticDataReference(sample_id)"
    ),
    stringr::str_c(
      "CREATE INDEX idx_abioticdatareference_sample_ref_id ",
      "ON AbioticDataReference(sample_ref_id)"
    )
  )

data_write_variants <-
  tibble::tribble(
    ~variant, ~flag_indexes_first,
    "v1_copy_to", TRUE,
    "copy_to_no_analyze", TRUE,
    "append_then_index", FALSE
  )

data_write_results <-
  data_write_variants |>
  dplyr::mutate(
    result = purrr::map2(
      .x = variant,
      .y = flag_indexes_first,
      .f = ~ {
        name_variant <- .x

        flag_indexes_now <- .y

        path_db <-
          base::file.path(path_run, stringr::str_c(name_variant, ".sqlite"))

        # Connected as v1 connects, with the RSQLite defaults
        con_write <-
          DBI::dbConnect(
            drv = RSQLite::SQLite(),
            dbname = path_db
          )

        data_variant <-
          tryCatch(
            expr = {
              DBI::dbExecute(conn = con_write, statement = sql_create_links)

              if (
                base::isTRUE(flag_indexes_now)
              ) {
                purrr::walk(
                  .x = vec_sql_create_indexes,
                  .f = ~ DBI::dbExecute(conn = con_write, statement = .x)
                )
              }

              data_batch_seconds <-
                data_write_batches |>
                dplyr::mutate(
                  seconds = purrr::map2_dbl(
                    .x = row_from,
                    .y = row_to,
                    .f = ~ {
                      data_chunk <-
                        vctrs::vec_slice(
                          data_links,
                          base::seq.int(from = .x, to = .y)
                        )

                      time_write_start <-
                        base::Sys.time()

                      if (
                        name_variant == "v1_copy_to"
                      ) {
                        dplyr::copy_to(
                          dest = con_write,
                          df = data_chunk,
                          name = "AbioticDataReference",
                          append = TRUE
                        )
                      } else if (
                        name_variant == "copy_to_no_analyze"
                      ) {
                        dplyr::copy_to(
                          dest = con_write,
                          df = data_chunk,
                          name = "AbioticDataReference",
                          append = TRUE,
                          analyze = FALSE
                        )
                      } else {
                        DBI::dbAppendTable(
                          conn = con_write,
                          name = "AbioticDataReference",
                          value = data_chunk
                        )
                      }

                      base::difftime(
                        base::Sys.time(),
                        time_write_start,
                        units = "secs"
                      ) |>
                        base::as.numeric()
                    }
                  )
                )

              time_index_last_start <-
                base::Sys.time()

              if (
                base::isFALSE(flag_indexes_now)
              ) {
                purrr::walk(
                  .x = vec_sql_create_indexes,
                  .f = ~ DBI::dbExecute(conn = con_write, statement = .x)
                )
              }

              seconds_index_last <-
                base::difftime(
                  base::Sys.time(),
                  time_index_last_start,
                  units = "secs"
                ) |>
                base::as.numeric()

              # Statistics written by the copy_to() writes, before the one
              #   `ANALYZE` below
              flag_statistics_by_writes <-
                DBI::dbExistsTable(conn = con_write, name = "sqlite_stat1")

              time_analyze_start <-
                base::Sys.time()

              if (
                base::isFALSE(flag_indexes_now)
              ) {
                DBI::dbExecute(
                  conn = con_write,
                  statement = "ANALYZE AbioticDataReference"
                )
              }

              seconds_analyze_full <-
                base::difftime(
                  base::Sys.time(),
                  time_analyze_start,
                  units = "secs"
                ) |>
                base::as.numeric()

              n_rows_written <-
                DBI::dbGetQuery(
                  conn = con_write,
                  statement = "SELECT count(*) AS n FROM AbioticDataReference"
                ) |>
                dplyr::pull(n)

              list(
                batches = data_batch_seconds,
                summary = tibble::tibble(
                  n_rows_written = n_rows_written,
                  seconds_writes = data_batch_seconds |>
                    dplyr::pull(seconds) |>
                    base::sum(),
                  seconds_index_last = seconds_index_last,
                  seconds_analyze_full = dplyr::if_else(
                    condition = flag_indexes_now,
                    true = NA_real_,
                    false = seconds_analyze_full
                  ),
                  flag_statistics_by_writes = flag_statistics_by_writes
                )
              )
            },
            finally = DBI::dbDisconnect(con_write)
          )

        # The file is disposable; only its size is kept
        size_db <-
          base::file.size(path_db)

        base::unlink(path_db)

        list(
          batches = purrr::chuck(data_variant, "batches"),
          summary = purrr::chuck(data_variant, "summary") |>
            dplyr::mutate(size_bytes = size_db)
        )
      }
    )
  )

table_write_batches <-
  data_write_results |>
  dplyr::mutate(
    batches = purrr::map(.x = result, .f = ~ purrr::chuck(.x, "batches"))
  ) |>
  dplyr::select(variant, batches) |>
  tidyr::unnest(cols = batches)

table_write_summary <-
  data_write_results |>
  dplyr::mutate(
    summary = purrr::map(.x = result, .f = ~ purrr::chuck(.x, "summary"))
  ) |>
  dplyr::select(variant, flag_indexes_first, summary) |>
  tidyr::unnest(cols = summary)

assertthat::assert_that(
  base::all(
    table_write_summary |>
      dplyr::pull(n_rows_written) == n_links
  ),
  msg = "A write variant did not write every link."
)


#----------------------------------------------------------#
# 3. Save results -----
#----------------------------------------------------------#

data_run_info <-
  tibble::tibble(
    script = "10_benchmark_link_writes.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    n_links = n_links,
    n_write_batches = n_write_batches,
    seconds_links_read = seconds_links_read,
    dbplyr_version = base::as.character(
      utils::packageVersion("dbplyr")
    ),
    rsqlite_version = base::as.character(
      utils::packageVersion("RSQLite")
    ),
    sqlite_version = RSQLite::rsqliteVersion() |>
      purrr::chuck(2L)
  )

list_outputs <-
  list(
    run_info = data_run_info,
    in_query_runs = data_in_query_runs,
    read_runs = data_read_runs,
    write_batches = table_write_batches,
    write_summary = table_write_summary
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
    "v" = "Link query, reads, and writes benchmarked.",
    "i" = "Results saved to {.path {path_run}}."
  )
)
