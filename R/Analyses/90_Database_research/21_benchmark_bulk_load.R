#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Benchmark bulk-load settings, VACUUM, ANALYZE and the
#              distribution of the database file
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Measure the bulk-load practice of question 6 on the full-size position
#   tables that 20_run_full_size_links.R wrote from v1.0.0 (95.3 M links,
#   10 M mapped samples), which are too large for the page cache to hide
#   the cost of the settings:
#   1. Read the four tables once and save them as a qs2 file, so that every
#      run loads the same data in memory.
#   2. Load them with every variant of `bulk_load` in research_settings.yml
#      (one change at a time from a baseline: PRAGMAs, page size, indexes
#      before or after loading, key order, transactions), each run in a new
#      R process (21a_run_bulk_load.R), `n_repetitions` times, interleaved.
#      The first baseline run also times `foreign_key_check`, `quick_check`
#      and `integrity_check`, and its file is kept; all other files are
#      deleted once measured.
#   3. On the kept file: `ANALYZE` with `analysis_limit`, `VACUUM INTO` a
#      new file and `VACUUM` in place, each in a new R process while the
#      free space of drives C: (temporary files) and D: is polled.
#   4. Distribution: SHA-256 and MD5 checksums, and gzip and xz compression
#      and decompression of the kept file, and xz of the `v1` and
#      `tuple_links` prototypes of question 4, to compare the two layouts.
# No database other than the files of this run is written; the source
#   files are opened read-only. Each call writes a new folder
#   `run_<timestamp>` under `Data/Temp/Database_research/Bulk_load` and
#   overwrites nothing; a failed call is restarted in a new folder.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/21_benchmark_bulk_load.R
#     <run folder of script 20 (the v1 target)> <run folder of script 13>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 2L,
  stringr::str_detect(purrr::chuck(vec_args, 1L), "^run_[0-9_]+_v1$"),
  stringr::str_detect(purrr::chuck(vec_args, 2L), "^run_[0-9_]+$"),
  msg = "Give the v1 run folder of script 20 and the run folder of 13."
)

list_settings_bulk <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  ) |>
  purrr::chuck("bulk_load")

path_research <-
  here::here("Data", "Temp", "Database_research")

path_links_source <-
  base::file.path(
    path_research, "Full_links", purrr::chuck(vec_args, 1L), "links.sqlite"
  )

path_prototypes <-
  base::file.path(path_research, "Prototypes", purrr::chuck(vec_args, 2L))

vec_tool_paths <-
  c(
    gzip = purrr::chuck(list_settings_bulk, "gzip_exe"),
    xz = purrr::chuck(list_settings_bulk, "xz_exe"),
    sha256sum = purrr::chuck(list_settings_bulk, "sha256sum_exe")
  )

assertthat::assert_that(
  base::file.exists(path_links_source),
  base::file.exists(base::file.path(path_prototypes, "v1.sqlite")),
  base::file.exists(base::file.path(path_prototypes, "tuple_links.sqlite")),
  base::all(base::file.exists(vec_tool_paths)),
  msg = "A source file or a tool is missing."
)

time_run_start <-
  base::Sys.time()

path_run <-
  base::file.path(
    path_research,
    "Bulk_load",
    stringr::str_c("run_", base::format(time_run_start, "%Y%m%d_%H%M%S"))
  )

assertthat::assert_that(
  !base::dir.exists(path_run),
  msg = "The run folder exists already."
)

base::dir.create(path = base::file.path(path_run, "logs"), recursive = TRUE)

path_child_script <-
  here::here("R/Analyses/90_Database_research/21a_run_bulk_load.R")

path_rscript <-
  base::file.path(base::R.home("bin"), "Rscript")

path_source_qs2 <-
  base::file.path(path_run, "source.qs2")

vec_variant_names <-
  purrr::chuck(list_settings_bulk, "variants") |>
  purrr::map_chr(.f = ~ purrr::chuck(.x, "name"))

data_source_state <-
  tibble::tibble(
    path = c(
      path_links_source,
      base::file.path(path_prototypes, "v1.sqlite"),
      base::file.path(path_prototypes, "tuple_links.sqlite")
    ),
    size_before = base::file.size(path),
    mtime_before = base::file.mtime(path)
  )


#----------------------------------------------------------#
# 1. The source tables, once -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

con_links <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_links_source,
    flags = RSQLite::SQLITE_RO
  )

list_source <-
  c(
    Positions = "SELECT * FROM Positions ORDER BY position_id",
    Gridpoints = "SELECT * FROM Gridpoints ORDER BY gridpoint_id",
    SamplePosition = "SELECT * FROM SamplePosition ORDER BY sample_id",
    PositionLink = stringr::str_c(
      "SELECT * FROM PositionLink ORDER BY position_id, gridpoint_id"
    )
  ) |>
  purrr::map(
    .f = ~ DBI::dbGetQuery(con_links, .x) |>
      tibble::as_tibble()
  )

DBI::dbDisconnect(con_links)

qs2::qs_save(object = list_source, file = path_source_qs2, nthreads = 4L)

data_source_info <-
  tibble::tibble(
    table_name = base::names(list_source),
    n_rows = list_source |>
      purrr::map_int(.f = base::nrow)
  ) |>
  dplyr::mutate(
    seconds_read_and_save = base::difftime(
      base::Sys.time(), time_step_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    qs2_bytes = base::file.size(path_source_qs2)
  )

base::rm(list_source)

readr::write_csv(
  x = data_source_info,
  file = base::file.path(path_run, "source_info.csv")
)


#----------------------------------------------------------#
# 2. Load variants -----
#----------------------------------------------------------#

data_runs <-
  tidyr::expand_grid(
    repetition = base::seq_len(
      purrr::chuck(list_settings_bulk, "n_repetitions")
    ),
    variant = vec_variant_names
  ) |>
  dplyr::mutate(
    label = stringr::str_c(variant, "_rep", repetition),
    flag_keep = variant == "baseline" & repetition == 1L,
    path_output = base::file.path(path_run, stringr::str_c(label, ".sqlite")),
    path_log_prefix = base::file.path(path_run, "logs", label)
  )

data_run_status <-
  data_runs |>
  dplyr::mutate(
    result = purrr::pmap(
      .l = list(label, variant, flag_keep, path_output, path_log_prefix),
      .f = ~ {
        # cli templates cannot start with a dot, so the arguments get names
        name_label_now <- ..1

        cli::cli_inform("Loading {name_label_now}.")

        time_child_start <-
          base::Sys.time()

        res_child <-
          processx::run(
            command = path_rscript,
            args = c(
              path_child_script,
              "load",
              path_source_qs2,
              ..4,
              ..2,
              dplyr::if_else(..3, "yes", "no"),
              ..5
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
          con = stringr::str_c(..5, ".log")
        )

        if (
          base::isFALSE(..3)
        ) {
          base::unlink(..4)
        }

        tibble::tibble(
          exit_status = purrr::chuck(res_child, "status"),
          timed_out = purrr::chuck(res_child, "timeout"),
          seconds_child = base::difftime(
            base::Sys.time(), time_child_start,
            units = "secs"
          ) |>
            base::as.numeric()
        )
      }
    )
  ) |>
  tidyr::unnest(result)

readr::write_csv(
  x = data_run_status |> dplyr::select(-path_output, -path_log_prefix),
  file = base::file.path(path_run, "run_status.csv")
)

assertthat::assert_that(
  base::all(data_run_status |> dplyr::pull(exit_status) == 0L),
  msg = "A load run failed; see the logs."
)

data_steps <-
  data_runs |>
  dplyr::select(label, repetition, path_log_prefix) |>
  dplyr::mutate(
    data = purrr::map(
      .x = path_log_prefix,
      .f = ~ readr::read_csv(
        stringr::str_c(.x, "_steps.csv"),
        show_col_types = FALSE,
        num_threads = 1L
      )
    )
  ) |>
  dplyr::select(-path_log_prefix) |>
  tidyr::unnest(data)

data_files <-
  data_runs |>
  dplyr::select(label, repetition, path_log_prefix) |>
  dplyr::mutate(
    data = purrr::map(
      .x = path_log_prefix,
      .f = ~ readr::read_csv(
        stringr::str_c(.x, "_file.csv"),
        show_col_types = FALSE,
        num_threads = 1L
      )
    )
  ) |>
  dplyr::select(-path_log_prefix) |>
  tidyr::unnest(data)

readr::write_csv(
  x = data_steps,
  file = base::file.path(path_run, "steps.csv")
)

readr::write_csv(
  x = data_files,
  file = base::file.path(path_run, "files.csv")
)

data_variant_summary <-
  data_steps |>
  dplyr::filter(
    step %in% c("setup", "load", "index", "finish", "analyze")
  ) |>
  dplyr::summarise(
    seconds_total = base::sum(seconds),
    .by = c(variant, repetition)
  ) |>
  dplyr::left_join(
    data_steps |>
      dplyr::filter(
        step %in% c("setup", "load", "index", "finish", "analyze")
      ) |>
      tidyr::pivot_wider(
        id_cols = c(variant, repetition),
        names_from = step,
        values_from = seconds,
        names_prefix = "seconds_"
      ),
    by = c("variant", "repetition")
  ) |>
  dplyr::left_join(
    data_files |>
      dplyr::select(variant, repetition, file_bytes, peak_wset_mb),
    by = c("variant", "repetition")
  )

readr::write_csv(
  x = data_variant_summary,
  file = base::file.path(path_run, "variant_summary.csv")
)


#----------------------------------------------------------#
# 3. ANALYZE and VACUUM on the kept baseline file -----
#----------------------------------------------------------#

path_kept <-
  data_runs |>
  dplyr::filter(flag_keep) |>
  dplyr::pull(path_output)

con_kept <-
  DBI::dbConnect(RSQLite::SQLite(), path_kept)

data_analyze <-
  c(0L, 1000L, 400L) |>
  purrr::map(
    .f = ~ {
      DBI::dbExecute(
        con_kept,
        stringr::str_c("PRAGMA analysis_limit = ", .x)
      )

      time_analyze_start <-
        base::Sys.time()

      DBI::dbExecute(con_kept, "ANALYZE main")

      tibble::tibble(
        analysis_limit = .x,
        seconds = base::difftime(
          base::Sys.time(), time_analyze_start,
          units = "secs"
        ) |>
          base::as.numeric()
      )
    }
  ) |>
  dplyr::bind_rows()

# Leave the file with full statistics
DBI::dbExecute(con_kept, "PRAGMA analysis_limit = 0")

DBI::dbExecute(con_kept, "ANALYZE main")

DBI::dbDisconnect(con_kept)

readr::write_csv(
  x = data_analyze,
  file = base::file.path(path_run, "analyze.csv")
)

path_vacuum_into <-
  base::file.path(path_run, "vacuum_into.sqlite")

# Each VACUUM runs in its own process while the free space is polled
data_vacuum <-
  c("into", "in_place") |>
  purrr::map(
    .f = ~ {
      name_vacuum <- .x

      cli::cli_inform("VACUUM, {name_vacuum}.")

      path_log_prefix_vacuum <-
        base::file.path(path_run, "logs", stringr::str_c("vacuum_", .x))

      path_vacuum_log <-
        stringr::str_c(path_log_prefix_vacuum, "_vacuum.csv")

      data_disk_before <-
        ps::ps_disk_usage(c("C:/", "D:/")) |>
        dplyr::select(mountpoint, available)

      # The child runs in the background; it writes its log when VACUUM is
      #   done
      # R.home() gives a path without spaces; only the arguments are quoted
      base::system2(
        command = path_rscript,
        args = base::shQuote(
          c(
            path_child_script,
            "vacuum",
            path_kept,
            .x,
            path_vacuum_into,
            path_log_prefix_vacuum
          )
        ),
        stdout = stringr::str_c(path_log_prefix_vacuum, ".log"),
        stderr = stringr::str_c(path_log_prefix_vacuum, "_err.log"),
        wait = FALSE
      )

      # Smallest free space seen on each drive while VACUUM runs (at most
      #   one hour)
      data_disk_min <-
        purrr::reduce(
          .x = base::seq_len(36000L),
          .f = ~ {
            if (
              base::file.exists(path_vacuum_log)
            ) {
              purrr::done(.x)
            } else {
              base::Sys.sleep(0.1)

              ps::ps_disk_usage(c("C:/", "D:/")) |>
                dplyr::select(mountpoint, available) |>
                dplyr::bind_rows(.x) |>
                dplyr::summarise(
                  available = base::min(available),
                  .by = mountpoint
                )
            }
          },
          .init = data_disk_before
        )

      assertthat::assert_that(
        base::file.exists(path_vacuum_log),
        msg = "VACUUM did not finish within an hour; see its log."
      )

      readr::read_csv(
        path_vacuum_log,
        show_col_types = FALSE,
        num_threads = 1L
      ) |>
        dplyr::mutate(
          extra_gb_c = (
            data_disk_before |>
              dplyr::filter(mountpoint == "C:/") |>
              dplyr::pull(available) -
              data_disk_min |>
              dplyr::filter(mountpoint == "C:/") |>
              dplyr::pull(available)
          ) / 1e9,
          extra_gb_d = (
            data_disk_before |>
              dplyr::filter(mountpoint == "D:/") |>
              dplyr::pull(available) -
              data_disk_min |>
              dplyr::filter(mountpoint == "D:/") |>
              dplyr::pull(available)
          ) / 1e9
        )
    }
  ) |>
  dplyr::bind_rows()

base::unlink(path_vacuum_into)

readr::write_csv(
  x = data_vacuum,
  file = base::file.path(path_run, "vacuum.csv")
)


#----------------------------------------------------------#
# 4. Distribution: checksums and compression -----
#----------------------------------------------------------#

data_compress_files <-
  tibble::tribble(
    ~file_label, ~path,
    "position_tables_v1_size", path_kept,
    "prototype_v1_layout_subset", base::file.path(
      path_prototypes, "v1.sqlite"
    ),
    "prototype_tuple_links_subset", base::file.path(
      path_prototypes, "tuple_links.sqlite"
    )
  ) |>
  dplyr::mutate(bytes = base::file.size(path))

# Checksums of the kept file
time_checksum_start <-
  base::Sys.time()

res_sha256 <-
  processx::run(
    command = purrr::chuck(vec_tool_paths, "sha256sum"),
    args = path_kept
  )

seconds_sha256 <-
  base::difftime(base::Sys.time(), time_checksum_start, units = "secs") |>
  base::as.numeric()

time_checksum_start <-
  base::Sys.time()

text_md5 <-
  tools::md5sum(path_kept)

seconds_md5 <-
  base::difftime(base::Sys.time(), time_checksum_start, units = "secs") |>
  base::as.numeric()

readr::write_csv(
  x = tibble::tibble(
    algorithm = c("sha256", "md5"),
    seconds = c(seconds_sha256, seconds_md5),
    bytes = base::file.size(path_kept),
    hash = c(
      purrr::chuck(res_sha256, "stdout") |>
        stringr::str_extract("^[0-9a-f]{64}"),
      base::unname(text_md5)
    )
  ),
  file = base::file.path(path_run, "checksums.csv")
)

# gzip on the kept file only; xz on all three
data_compress_runs <-
  dplyr::bind_rows(
    data_compress_files |>
      dplyr::filter(file_label == "position_tables_v1_size") |>
      dplyr::mutate(
        tool = "gzip",
        args_compress = purrr::map(.x = path, .f = ~ c("-6", "-c", .x)),
        suffix = ".gz"
      ),
    data_compress_files |>
      dplyr::mutate(
        tool = "xz",
        args_compress = purrr::map(
          .x = path,
          .f = ~ c(
            "-6",
            stringr::str_c(
              "-T", purrr::chuck(list_settings_bulk, "xz_threads")
            ),
            "-c", .x
          )
        ),
        suffix = ".xz"
      )
  )

data_compression <-
  data_compress_runs |>
  dplyr::mutate(
    result = purrr::pmap(
      .l = list(file_label, tool, args_compress, suffix),
      .f = ~ {
        path_compressed <-
          base::file.path(path_run, stringr::str_c(..1, ..4))

        name_compress_label <- ..1

        name_tool <- ..2

        cli::cli_inform("Compressing {name_compress_label} with {name_tool}.")

        time_compress_start <-
          base::Sys.time()

        processx::run(
          command = purrr::chuck(vec_tool_paths, ..2),
          args = ..3,
          stdout = path_compressed
        )

        seconds_compress <-
          base::difftime(
            base::Sys.time(), time_compress_start,
            units = "secs"
          ) |>
          base::as.numeric()

        time_decompress_start <-
          base::Sys.time()

        processx::run(
          command = purrr::chuck(vec_tool_paths, ..2),
          args = c(
            "-d", "-c",
            if (
              ..2 == "xz"
            ) {
              stringr::str_c(
                "-T", purrr::chuck(list_settings_bulk, "xz_threads")
              )
            } else {
              base::character()
            },
            path_compressed
          ),
          stdout = NULL
        )

        seconds_decompress <-
          base::difftime(
            base::Sys.time(), time_decompress_start,
            units = "secs"
          ) |>
          base::as.numeric()

        bytes_compressed <-
          base::file.size(path_compressed)

        base::unlink(path_compressed)

        tibble::tibble(
          seconds_compress = seconds_compress,
          seconds_decompress = seconds_decompress,
          bytes_compressed = bytes_compressed
        )
      }
    )
  ) |>
  tidyr::unnest(result) |>
  dplyr::select(-args_compress, -path) |>
  dplyr::mutate(ratio = bytes / bytes_compressed)

readr::write_csv(
  x = data_compression,
  file = base::file.path(path_run, "compression.csv")
)


#----------------------------------------------------------#
# 5. Record the run -----
#----------------------------------------------------------#

base::unlink(path_source_qs2)

flag_sources_unchanged <-
  data_source_state |>
  dplyr::mutate(
    unchanged = base::file.size(path) == size_before &
      base::file.mtime(path) == mtime_before
  ) |>
  dplyr::pull(unchanged) |>
  base::all()

readr::write_csv(
  x = tibble::tibble(
    script = "21_benchmark_bulk_load.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(), time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    n_repetitions = purrr::chuck(list_settings_bulk, "n_repetitions"),
    n_variants = base::length(vec_variant_names),
    r_version = base::as.character(base::getRversion()),
    rsqlite_version = base::as.character(
      utils::packageVersion("RSQLite")
    ),
    temp_dir = base::Sys.getenv("TEMP"),
    sources_unchanged = flag_sources_unchanged
  ),
  file = base::file.path(path_run, "run_info.csv")
)

assertthat::assert_that(
  base::isTRUE(flag_sources_unchanged),
  msg = "A source file changed during the run."
)

cli::cli_inform(
  c(
    "v" = "Benchmarked the bulk-load practice.",
    "i" = "Results in {.path {path_run}}."
  )
)
