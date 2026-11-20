#----------------------------------------------------------#
#
#
#                       VegVault
#
#              Inspect the v1.0.0 database file
#                - metadata and schema only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Record the page-level metadata, schema, version rows, ANALYZE statistics,
#   and rowid bounds of the released v1.0.0 SQLite file. Every query is
#   answered from the file header, the schema, or a single b-tree descent,
#   so no table is scanned. The file is opened read-only, and its size,
#   modification time, and header are compared before and after the queries.
#   Nothing printed or saved contains the file path.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (resolves `path_to_vegvault` from the secrets file)
source(
  here::here("R/00_Config_file.R")
)

path_output <-
  here::here("Data", "Temp", "Database_research", "V1_metadata")

base::dir.create(
  path = path_output,
  recursive = TRUE,
  showWarnings = FALSE
)

path_make_tables <-
  here::here("Data", "SQL", "make_tables.sql")

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

time_run_start <-
  base::Sys.time()

assertthat::assert_that(
  base::file.exists(path_to_vegvault),
  msg = "The database file named in the secrets file does not exist."
)


#----------------------------------------------------------#
# 1. Record the file state before connecting -----
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

vec_sibling_exists_before <-
  base::file.exists(
    stringr::str_c(path_to_vegvault, vec_sibling_suffix)
  )

assertthat::assert_that(
  base::rawToChar(vec_header_raw_before[1:15]) == "SQLite format 3",
  msg = "The configured file is not an SQLite database."
)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only opened when it uses a rollback journal (header byte 19 = 1)
if (
  base::as.integer(vec_header_raw_before[19L]) != 1L ||
    base::as.integer(vec_header_raw_before[20L]) != 1L
) {
  cli::cli_abort(
    c(
      "The database file is not in rollback-journal mode.",
      "i" = "It was not opened, to avoid creating files next to it."
    )
  )
}

if (
  base::any(vec_sibling_exists_before)
) {
  cli::cli_abort(
    c(
      "A journal, WAL or shm file already exists next to the database.",
      "i" = "Another process may be using it; it was not opened."
    )
  )
}


#----------------------------------------------------------#
# 2. Query metadata through a read-only connection -----
#----------------------------------------------------------#

con_v1 <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_to_vegvault,
    flags = RSQLite::SQLITE_RO,
    bigint = "numeric"
  )

tryCatch(
  expr = {
    #--------------------------------------------------#
    ## 2.1. PRAGMAs -----
    #--------------------------------------------------#

    vec_pragma_names <-
      c(
        "page_size",
        "page_count",
        "freelist_count",
        "journal_mode",
        "auto_vacuum",
        "encoding",
        "user_version",
        "application_id",
        "schema_version"
      )

    data_pragmas <-
      vec_pragma_names |>
      purrr::map(
        .f = ~ tibble::tibble(
          pragma = .x,
          value = DBI::dbGetQuery(
            conn = con_v1,
            statement = stringr::str_c("PRAGMA ", .x)
          ) |>
            dplyr::pull(var = 1) |>
            base::as.character()
        )
      ) |>
      dplyr::bind_rows()

    #--------------------------------------------------#
    ## 2.2. Schema objects -----
    #--------------------------------------------------#

    data_schema_objects <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT type, name, tbl_name, rootpage, sql ",
          "FROM sqlite_master ORDER BY type, tbl_name, name"
        )
      ) |>
      tibble::as_tibble()

    #--------------------------------------------------#
    ## 2.3. Version rows and ANALYZE statistics -----
    #--------------------------------------------------#

    data_version_control_v1 <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM version_control"
      ) |>
      tibble::as_tibble()

    vec_stat_tables <-
      data_schema_objects |>
      dplyr::filter(
        stringr::str_detect(name, "^sqlite_stat")
      ) |>
      dplyr::pull(name)

    # The first integer of `stat` is the row count of the table or index
    #   at the time ANALYZE ran
    data_sqlite_stat1 <-
      if (
        "sqlite_stat1" %in% vec_stat_tables
      ) {
        DBI::dbGetQuery(
          conn = con_v1,
          statement = "SELECT tbl, idx, stat FROM sqlite_stat1"
        ) |>
          tibble::as_tibble() |>
          dplyr::mutate(
            n_rows_at_analyze = stringr::str_extract(stat, "^[0-9]+") |>
              base::as.numeric()
          )
      } else {
        tibble::tibble(
          tbl = base::character(),
          idx = base::character(),
          stat = base::character(),
          n_rows_at_analyze = base::numeric()
        )
      }

    #--------------------------------------------------#
    ## 2.4. Rowid bounds per table -----
    #--------------------------------------------------#

    vec_table_names <-
      data_schema_objects |>
      dplyr::filter(
        type == "table",
        !stringr::str_detect(name, "^sqlite_")
      ) |>
      dplyr::pull(name)

    # SQLite answers a lone min() or max() of the rowid with one b-tree
    #   descent; combining both in one query would scan the table
    data_rowid_bounds <-
      vec_table_names |>
      purrr::map(
        .f = ~ {
          time_query_start <-
            base::Sys.time()

          value_min_rowid <-
            DBI::dbGetQuery(
              conn = con_v1,
              statement = stringr::str_c(
                "SELECT min(rowid) AS value FROM \"", .x, "\""
              )
            ) |>
            dplyr::pull(value)

          value_max_rowid <-
            DBI::dbGetQuery(
              conn = con_v1,
              statement = stringr::str_c(
                "SELECT max(rowid) AS value FROM \"", .x, "\""
              )
            ) |>
            dplyr::pull(value)

          tibble::tibble(
            table_name = .x,
            min_rowid = value_min_rowid,
            max_rowid = value_max_rowid,
            seconds = base::difftime(
              base::Sys.time(),
              time_query_start,
              units = "secs"
            ) |>
              base::as.numeric()
          )
        }
      ) |>
      dplyr::bind_rows()

    #--------------------------------------------------#
    ## 2.5. Small lookup tables -----
    #--------------------------------------------------#

    data_dataset_type <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM DatasetTypeID"
      ) |>
      tibble::as_tibble()

    data_dataset_source_type <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM DatasetSourceTypeID"
      ) |>
      tibble::as_tibble()

    data_abiotic_variable <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT abiotic_variable_id, abiotic_variable_name, ",
          "abiotic_variable_unit FROM AbioticVariable"
        )
      ) |>
      tibble::as_tibble()
  },
  finally = DBI::dbDisconnect(con_v1)
)


#----------------------------------------------------------#
# 3. Record the file state after disconnecting -----
#----------------------------------------------------------#

vec_header_raw_after <-
  base::readBin(
    con = path_to_vegvault,
    what = "raw",
    n = 100L
  )

size_bytes_after <-
  base::file.size(path_to_vegvault)

mtime_after <-
  base::file.mtime(path_to_vegvault)

vec_sibling_exists_after <-
  base::file.exists(
    stringr::str_c(path_to_vegvault, vec_sibling_suffix)
  )

data_file_state <-
  tibble::tibble(
    stage = c("before", "after"),
    size_bytes = c(size_bytes_before, size_bytes_after),
    mtime = base::format(
      c(mtime_before, mtime_after),
      format = "%Y-%m-%d %H:%M:%OS3"
    ),
    journal_exists = c(
      vec_sibling_exists_before[1L],
      vec_sibling_exists_after[1L]
    ),
    wal_exists = c(
      vec_sibling_exists_before[2L],
      vec_sibling_exists_after[2L]
    ),
    shm_exists = c(
      vec_sibling_exists_before[3L],
      vec_sibling_exists_after[3L]
    ),
    header_identical = c(
      TRUE,
      base::identical(vec_header_raw_before, vec_header_raw_after)
    )
  )

flag_file_unchanged <-
  base::isTRUE(
    size_bytes_before == size_bytes_after &&
      mtime_before == mtime_after &&
      base::identical(vec_header_raw_before, vec_header_raw_after) &&
      !base::any(vec_sibling_exists_after)
  )


#----------------------------------------------------------#
# 4. Decode the file header -----
#----------------------------------------------------------#

# Byte offsets and widths follow the SQLite file format specification
#   (https://www.sqlite.org/fileformat.html, section 1.3); all integers
#   are big-endian
data_header_spec <-
  tibble::tribble(
    ~header_field, ~byte_offset, ~n_bytes,
    "page_size_code", 16L, 2L,
    "write_version", 18L, 1L,
    "read_version", 19L, 1L,
    "reserved_bytes_per_page", 20L, 1L,
    "file_change_counter", 24L, 4L,
    "page_count", 28L, 4L,
    "first_freelist_trunk_page", 32L, 4L,
    "freelist_page_count", 36L, 4L,
    "schema_cookie", 40L, 4L,
    "schema_format", 44L, 4L,
    "default_cache_size", 48L, 4L,
    "largest_root_page_vacuum", 52L, 4L,
    "text_encoding", 56L, 4L,
    "user_version", 60L, 4L,
    "incremental_vacuum", 64L, 4L,
    "application_id", 68L, 4L,
    "version_valid_for", 92L, 4L,
    "sqlite_version_number", 96L, 4L
  )

data_header_bytes <-
  list(
    before = vec_header_raw_before,
    after = vec_header_raw_after
  ) |>
  purrr::imap(
    .f = ~ tibble::tibble(
      stage = .y,
      byte_position = base::seq_along(.x) - 1L,
      byte_value = base::as.numeric(.x)
    )
  ) |>
  dplyr::bind_rows()

data_header_positions <-
  data_header_spec |>
  dplyr::mutate(
    byte_position = purrr::map2(
      .x = byte_offset,
      .y = n_bytes,
      .f = ~ base::seq(from = .x, length.out = .y)
    )
  ) |>
  tidyr::unnest(cols = byte_position) |>
  dplyr::mutate(
    byte_weight = 256^(n_bytes - 1L - (byte_position - byte_offset))
  )

data_header_fields <-
  data_header_positions |>
  dplyr::inner_join(
    data_header_bytes,
    by = dplyr::join_by(byte_position),
    relationship = "one-to-many"
  ) |>
  dplyr::summarise(
    value = base::sum(byte_value * byte_weight),
    .by = c(stage, header_field)
  ) |>
  tidyr::pivot_wider(
    names_from = stage,
    values_from = value
  )


#----------------------------------------------------------#
# 5. Compare the stored schema with make_tables.sql -----
#----------------------------------------------------------#

data_make_tables_objects <-
  base::readLines(
    con = path_make_tables,
    warn = FALSE
  ) |>
  stringr::str_c(collapse = "\n") |>
  stringr::str_split(pattern = ";") |>
  purrr::pluck(1L) |>
  stringr::str_squish() |>
  purrr::discard(.p = ~ .x == "") |>
  tibble::tibble(sql_make_tables = _) |>
  dplyr::mutate(
    type = dplyr::if_else(
      stringr::str_detect(sql_make_tables, "(?i)^CREATE TABLE"),
      "table",
      "index"
    ),
    name = stringr::str_match(
      sql_make_tables,
      "(?i)^CREATE (?:UNIQUE )?(?:TABLE|INDEX) \"?([A-Za-z_]+)\"?"
    )[, 2]
  )

data_schema_comparison <-
  data_schema_objects |>
  dplyr::filter(
    type %in% c("table", "index"),
    !base::is.na(sql),
    !stringr::str_detect(name, "^sqlite_")
  ) |>
  dplyr::select(type, name, sql_v1 = sql) |>
  dplyr::full_join(
    data_make_tables_objects,
    by = dplyr::join_by(type, name)
  ) |>
  dplyr::mutate(
    sql_v1_normalised = stringr::str_remove_all(
      stringr::str_to_lower(sql_v1),
      "[[:space:]\"]"
    ),
    sql_make_tables_normalised = stringr::str_remove_all(
      stringr::str_to_lower(sql_make_tables),
      "[[:space:]\"]"
    ),
    status = dplyr::case_when(
      base::is.na(sql_v1) ~ "only in make_tables.sql",
      base::is.na(sql_make_tables) ~ "only in v1.0.0",
      sql_v1_normalised == sql_make_tables_normalised ~ "identical",
      .default = "different"
    )
  ) |>
  dplyr::select(type, name, status, sql_v1, sql_make_tables)


#----------------------------------------------------------#
# 6. Save results -----
#----------------------------------------------------------#

data_run_info <-
  tibble::tibble(
    script = "01_inspect_v1_metadata.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    r_version = base::as.character(base::getRversion()),
    rsqlite_version = base::as.character(
      utils::packageVersion("RSQLite")
    ),
    sqlite_library_version = RSQLite::rsqliteVersion()[["library"]],
    connection_flags = "SQLITE_RO",
    file_unchanged = flag_file_unchanged
  )

list_outputs <-
  list(
    run_info = data_run_info,
    file_state = data_file_state,
    header_fields = data_header_fields,
    pragmas = data_pragmas,
    schema_objects = data_schema_objects,
    schema_comparison = data_schema_comparison,
    version_control = data_version_control_v1,
    sqlite_stat1 = data_sqlite_stat1,
    rowid_bounds = data_rowid_bounds,
    dataset_type = data_dataset_type,
    dataset_source_type = data_dataset_source_type,
    abiotic_variable = data_abiotic_variable
  )

purrr::iwalk(
  .x = list_outputs,
  .f = ~ readr::write_csv(
    x = .x,
    file = base::file.path(path_output, stringr::str_c(.y, ".csv"))
  )
)


#----------------------------------------------------------#
# 7. Check that the file was not changed -----
#----------------------------------------------------------#

if (
  base::isFALSE(flag_file_unchanged)
) {
  cli::cli_abort(
    c(
      "The database file differs after the read-only session.",
      "i" = "Compare `file_state.csv` and `header_fields.csv`."
    )
  )
}

cli::cli_inform(
  c(
    "v" = "Read-only session finished; the file is unchanged.",
    "i" = "Results saved to {.path Data/Temp/Database_research/V1_metadata}."
  )
)
