#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Load the position tables under one set of settings
#         - called by 21_benchmark_bulk_load.R only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Two modes, each in its own R process:
#   - `load`: write the full-size position tables (Positions, Gridpoints,
#     SamplePosition, PositionLink, from the qs2 file prepared by the
#     parent) into a new SQLite file under the settings of one variant of
#     `bulk_load` in research_settings.yml (the baseline with the variant's
#     changes): page size, journal mode, synchronous, foreign keys, temp
#     store and cache size; secondary indexes before or after loading; rows
#     in key order or shuffled; one transaction or one per chunk of
#     positions. Every step is timed, and the peak memory of the process is
#     recorded. With `extra_checks = yes`, `foreign_key_check`,
#     `quick_check` and `integrity_check` are timed as well.
#   - `vacuum`: run `VACUUM` on a file in place, or `VACUUM INTO` a new
#     file, and time it; the parent measures the disk use meanwhile.
# Only files of the benchmark run folder are written.
#
# Arguments:
#   load <source qs2> <output file> <variant> <yes|no> <log prefix>
#   vacuum <database file> <in_place|into> <target file> <log prefix>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

name_mode <-
  purrr::chuck(vec_args, 1L)

assertthat::assert_that(
  (name_mode == "load" && base::length(vec_args) == 6L) ||
    (name_mode == "vacuum" && base::length(vec_args) == 5L),
  msg = "Give `load` with five arguments or `vacuum` with four."
)

path_log_prefix <-
  dplyr::last(vec_args)

list_settings_bulk <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  ) |>
  purrr::chuck("bulk_load")


#----------------------------------------------------------#
# 1. vacuum -----
#----------------------------------------------------------#

if (
  name_mode == "vacuum"
) {
  path_db <-
    purrr::chuck(vec_args, 2L)

  name_vacuum <-
    purrr::chuck(vec_args, 3L)

  path_target <-
    purrr::chuck(vec_args, 4L)

  assertthat::assert_that(
    name_vacuum %in% c("in_place", "into"),
    base::file.exists(path_db),
    msg = "Unknown vacuum mode, or no database."
  )

  bytes_before <-
    base::file.size(path_db)

  con_vacuum <-
    DBI::dbConnect(RSQLite::SQLite(), path_db)

  time_vacuum_start <-
    base::Sys.time()

  if (
    name_vacuum == "in_place"
  ) {
    DBI::dbExecute(con_vacuum, "VACUUM")
  } else {
    assertthat::assert_that(
      !base::file.exists(path_target),
      msg = "The target of VACUUM INTO exists already."
    )

    DBI::dbExecute(con_vacuum, "VACUUM INTO ?", params = list(path_target))
  }

  seconds_vacuum <-
    base::difftime(base::Sys.time(), time_vacuum_start, units = "secs") |>
    base::as.numeric()

  DBI::dbDisconnect(con_vacuum)

  # Written under a temporary name and renamed, so that the parent, which
  #   waits for this file, never reads it half written
  path_vacuum_log <-
    stringr::str_c(path_log_prefix, "_vacuum.csv")

  readr::write_csv(
    x = tibble::tibble(
      mode = name_vacuum,
      seconds = seconds_vacuum,
      bytes_before = bytes_before,
      bytes_after = dplyr::if_else(
        name_vacuum == "in_place",
        base::file.size(path_db),
        base::file.size(path_target)
      ),
      peak_wset_mb = purrr::chuck(
        ps::ps_memory_info(ps::ps_handle()), "peak_wset"
      ) / 1e6
    ),
    file = stringr::str_c(path_vacuum_log, ".tmp")
  )

  base::file.rename(
    from = stringr::str_c(path_vacuum_log, ".tmp"),
    to = path_vacuum_log
  )

  base::quit(save = "no", status = 0L)
}


#----------------------------------------------------------#
# 2. load: settings and data -----
#----------------------------------------------------------#

path_source <-
  purrr::chuck(vec_args, 2L)

path_db_out <-
  purrr::chuck(vec_args, 3L)

name_variant <-
  purrr::chuck(vec_args, 4L)

flag_extra_checks <-
  purrr::chuck(vec_args, 5L) == "yes"

list_variant <-
  purrr::chuck(list_settings_bulk, "variants") |>
  purrr::keep(.p = ~ purrr::chuck(.x, "name") == name_variant)

assertthat::assert_that(
  base::length(list_variant) == 1L,
  !base::file.exists(path_db_out),
  msg = "Unknown variant, or the output file exists already."
)

# The baseline with the changes of the variant
list_config <-
  purrr::list_modify(
    purrr::chuck(list_settings_bulk, "baseline"),
    !!!(purrr::chuck(list_variant, 1L) |> purrr::discard_at("name"))
  )

vec_table_sql <-
  readr::read_lines(
    here::here(
      "R/Analyses/90_Database_research/Prototype_schemas",
      "bulk_load_tables.sql"
    )
  ) |>
  stringr::str_subset(pattern = "^\\s*--", negate = TRUE) |>
  stringr::str_c(collapse = "\n") |>
  stringr::str_split(pattern = ";\\s*(\\n|$)") |>
  purrr::chuck(1L) |>
  stringr::str_trim() |>
  purrr::keep(.p = base::nzchar)

vec_index_sql <-
  readr::read_lines(
    here::here(
      "R/Analyses/90_Database_research/Prototype_schemas",
      "bulk_load_indexes.sql"
    )
  ) |>
  stringr::str_subset(pattern = "^\\s*--", negate = TRUE) |>
  stringr::str_c(collapse = "\n") |>
  stringr::str_split(pattern = ";\\s*(\\n|$)") |>
  purrr::chuck(1L) |>
  stringr::str_trim() |>
  purrr::keep(.p = base::nzchar)

# Reading the data and arranging it for the variant is not timed
list_data <-
  qs2::qs_read(path_source, nthreads = 4L)

if (
  purrr::chuck(list_config, "load_order") == "shuffled"
) {
  base::set.seed(purrr::chuck(list_settings_bulk, "seed"))

  list_data <-
    purrr::modify_in(
      .x = list_data,
      .where = "PositionLink",
      .f = ~ dplyr::slice_sample(.x, prop = 1)
    )
}

list_link_chunks <-
  if (
    purrr::chuck(list_config, "transactions") == "per_chunk"
  ) {
    purrr::chuck(list_data, "PositionLink") |>
      dplyr::mutate(
        chunk = (position_id - 1L) %/%
          purrr::chuck(list_settings_bulk, "chunk_size")
      ) |>
      dplyr::group_split(chunk, .keep = FALSE)
  } else {
    NULL
  }

data_step_log <-
  tibble::tibble(
    step = base::character(),
    seconds = base::numeric(),
    value = base::numeric()
  )


#----------------------------------------------------------#
# 3. load: write -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

con_out <-
  DBI::dbConnect(RSQLite::SQLite(), path_db_out)

# The page size must be set before the first table
DBI::dbExecute(
  con_out,
  stringr::str_c("PRAGMA page_size = ", purrr::chuck(list_config, "page_size"))
)

data_journal_mode <-
  DBI::dbGetQuery(
    con_out,
    stringr::str_c(
      "PRAGMA journal_mode = ", purrr::chuck(list_config, "journal_mode")
    )
  )

purrr::walk(
  .x = c("synchronous", "foreign_keys", "temp_store", "cache_size"),
  .f = ~ DBI::dbExecute(
    con_out,
    stringr::str_c("PRAGMA ", .x, " = ", purrr::chuck(list_config, .x))
  )
)

purrr::walk(
  .x = vec_table_sql,
  .f = ~ DBI::dbExecute(con_out, .x)
)

if (
  purrr::chuck(list_config, "index_timing") == "before"
) {
  purrr::walk(
    .x = vec_index_sql,
    .f = ~ DBI::dbExecute(con_out, .x)
  )
}

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "setup",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      value = NA_real_
    )
  )

time_step_start <-
  base::Sys.time()

# Parents first, so that foreign keys can be checked while loading
vec_tables_first <-
  if (
    purrr::chuck(list_config, "transactions") == "per_chunk"
  ) {
    c("Positions", "Gridpoints", "SamplePosition")
  } else {
    c("Positions", "Gridpoints", "SamplePosition", "PositionLink")
  }

DBI::dbBegin(con_out)

purrr::walk(
  .x = vec_tables_first,
  .f = ~ DBI::dbAppendTable(con_out, .x, purrr::chuck(list_data, .x))
)

DBI::dbCommit(con_out)

if (
  purrr::chuck(list_config, "transactions") == "per_chunk"
) {
  purrr::walk(
    .x = list_link_chunks,
    .f = ~ {
      DBI::dbBegin(con_out)

      DBI::dbAppendTable(con_out, "PositionLink", .x)

      DBI::dbCommit(con_out)
    }
  )
}

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "load",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      value = list_data |>
        purrr::map_int(.f = base::nrow) |>
        base::sum()
    )
  )

time_step_start <-
  base::Sys.time()

if (
  purrr::chuck(list_config, "index_timing") == "after"
) {
  purrr::walk(
    .x = vec_index_sql,
    .f = ~ DBI::dbExecute(con_out, .x)
  )
}

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "index",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      value = base::length(vec_index_sql)
    )
  )

time_step_start <-
  base::Sys.time()

# A WAL file is written back, so the result is one file
if (
  purrr::chuck(list_config, "journal_mode") == "WAL"
) {
  data_checkpoint <-
    DBI::dbGetQuery(con_out, "PRAGMA wal_checkpoint(TRUNCATE)")

  data_journal_mode <-
    DBI::dbGetQuery(con_out, "PRAGMA journal_mode = DELETE")
}

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "finish",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      value = NA_real_
    )
  )

time_step_start <-
  base::Sys.time()

DBI::dbExecute(con_out, "ANALYZE main")

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "analyze",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      value = NA_real_
    )
  )


#----------------------------------------------------------#
# 4. load: checks and the record -----
#----------------------------------------------------------#

if (
  base::isTRUE(flag_extra_checks)
) {
  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      c(
        foreign_key_check = "PRAGMA foreign_key_check",
        quick_check = "PRAGMA quick_check",
        integrity_check = "PRAGMA integrity_check"
      ) |>
        purrr::imap(
          .f = ~ {
            time_check_start <-
              base::Sys.time()

            data_check <-
              DBI::dbGetQuery(con_out, .x)

            tibble::tibble(
              step = .y,
              seconds = base::difftime(
                base::Sys.time(), time_check_start,
                units = "secs"
              ) |>
                base::as.numeric(),
              # Rows returned: 0 violations, or one row "ok"
              value = base::nrow(data_check)
            )
          }
        ) |>
        dplyr::bind_rows()
    )
}

data_pages <-
  tibble::tibble(
    page_size = DBI::dbGetQuery(con_out, "PRAGMA page_size") |>
      purrr::chuck(1L),
    page_count = DBI::dbGetQuery(con_out, "PRAGMA page_count") |>
      purrr::chuck(1L),
    freelist_count = DBI::dbGetQuery(con_out, "PRAGMA freelist_count") |>
      purrr::chuck(1L)
  )

DBI::dbDisconnect(con_out)

readr::write_csv(
  x = data_step_log |>
    dplyr::mutate(variant = name_variant, .before = 1L),
  file = stringr::str_c(path_log_prefix, "_steps.csv")
)

readr::write_csv(
  x = data_pages |>
    dplyr::mutate(
      variant = name_variant,
      file_bytes = base::file.size(path_db_out),
      peak_wset_mb = purrr::chuck(
        ps::ps_memory_info(ps::ps_handle()), "peak_wset"
      ) / 1e6,
      .before = 1L
    ),
  file = stringr::str_c(path_log_prefix, "_file.csv")
)
