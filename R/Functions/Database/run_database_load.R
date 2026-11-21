#' @title Run the bulk load of a database work file
#' @description
#' Load every table of a build into an empty SQLite work file and finish
#' it: create the schema tables, apply the load settings, write the tables
#' in schema order and in key order, create the indexes, run `ANALYZE`,
#' restore and check the safe settings, and copy the result to a new file
#' with `VACUUM INTO`.
#' @param con
#' A valid read-write `DBI` connection to an empty SQLite work file.
#' @param list_tables
#' Named list of data frames, named by schema table, with every id already
#' assigned (see `prepare_table_ids()`). Tables of the schema that are not
#' in the list stay empty.
#' @param path_vacuum_into
#' Character scalar. Path of the new file that `VACUUM INTO` writes. It
#' must not exist.
#' @param list_pragmas_load
#' Named list. Settings applied before the rows are loaded and checked
#' with `validate_database_pragmas()`, which lists the allowed names.
#' @param list_pragmas_final
#' Named list. Settings applied after `ANALYZE` and checked before
#' `VACUUM INTO`.
#' @param n_chunk_size
#' Whole number of at least 1. Rows per transaction (see
#' `save_database_table()`).
#' @param path_schema
#' Character scalar. Path of the schema file. Default:
#' `Data/SQL/make_tables.sql` of the project.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of two tibbles:
#' \itemize{
#'   \item `data_tables`: one row per table of the schema, in schema order:
#'     `table_name`, `n_rows`, `n_chunks` (integers) and `seconds`;
#'   \item `data_steps`: `step` and `seconds`, for the steps `schema`,
#'     `pragmas_load`, `tables`, `indexes`, `analyze`, `pragmas_final` and
#'     `vacuum_into`.
#' }
#' @details
#' The schema is created with `build_database_schema()`: the tables and
#' the view before the rows, the indexes after them. Foreign keys are not
#' enforced during the load (`foreign_keys = OFF` in the load settings);
#' the validation stage checks them once in the release file. Settings
#' are set with `PRAGMA <name> = <value>`, so their names must be allowed
#' names and their values whole numbers or single words.
#' Aborts before anything is written when `list_tables` names a table that
#' is not in the schema (the view `AbioticDataReference` included), when an
#' element is not a data frame, when the work file already holds a table,
#' or when `path_vacuum_into` exists. Any failed step aborts. The work file
#' is then incomplete and the caller discards it. The connection is never
#' closed here; use the function inside `run_with_database()`.
#' @seealso [save_vegvault_database()], [save_database_table()],
#' [build_database_schema()]
#' @examples
#' \dontrun{
#' list_summary <-
#'   run_with_database(
#'     path_database = path_work,
#'     fn = run_database_load,
#'     list_tables = list_tables,
#'     path_vacuum_into = path_new,
#'     list_pragmas_load = list_pragmas_load,
#'     list_pragmas_final = list_pragmas_final,
#'     n_chunk_size = 100000L
#'   )
#' }
run_database_load <- function(
  con,
  list_tables,
  path_vacuum_into,
  list_pragmas_load,
  list_pragmas_final,
  n_chunk_size,
  path_schema = here::here("Data", "SQL", "make_tables.sql"),
  verbose = TRUE
) {
  vec_pragma_names <-
    c("journal_mode", "synchronous", "foreign_keys", "temp_store", "cache_size")

  assertthat::assert_that(
    methods::is(con, "DBIConnection"),
    DBI::dbIsValid(con),
    msg = "`con` must be a valid DBI connection."
  )

  assertthat::assert_that(
    base::is.list(list_tables),
    !base::is.data.frame(list_tables),
    base::length(list_tables) >= 1L,
    !base::is.null(base::names(list_tables)),
    base::all(base::nzchar(base::names(list_tables))),
    !base::anyDuplicated(base::names(list_tables)),
    base::all(purrr::map_lgl(.x = list_tables, .f = base::is.data.frame)),
    msg = "`list_tables` must be a named list of data frames, one per table."
  )

  assertthat::assert_that(
    base::is.character(path_vacuum_into),
    base::length(path_vacuum_into) == 1L,
    !base::is.na(path_vacuum_into),
    base::nzchar(path_vacuum_into),
    msg = "`path_vacuum_into` must be a non-empty character scalar."
  )

  # Settings are written into the PRAGMA statement, so only allowed names
  #   and single words or whole numbers pass
  list_pragma_sets <-
    base::list(
      list_pragmas_load = list_pragmas_load,
      list_pragmas_final = list_pragmas_final
    )

  purrr::iwalk(
    .x = list_pragma_sets,
    .f = ~ {
      list_set <- .x

      name_set <- .y

      vec_values_safe <-
        purrr::map_lgl(
          .x = list_set,
          .f = ~ base::length(.x) == 1L &&
            !base::is.na(.x) &&
            stringr::str_detect(
              string = base::format(.x, scientific = FALSE),
              pattern = "^(-?[0-9]+|[A-Za-z]+)$"
            )
        )

      assertthat::assert_that(
        base::is.list(list_set),
        base::length(list_set) >= 1L,
        !base::is.null(base::names(list_set)),
        base::all(base::names(list_set) %in% vec_pragma_names),
        base::all(vec_values_safe),
        msg = stringr::str_c(
          "`", name_set, "` must be a named list of allowed settings (",
          stringr::str_c(vec_pragma_names, collapse = ", "),
          "), each a single word or a whole number."
        )
      )
    }
  )

  assertthat::assert_that(
    base::is.numeric(n_chunk_size),
    base::length(n_chunk_size) == 1L,
    !base::is.na(n_chunk_size),
    base::is.finite(n_chunk_size),
    n_chunk_size >= 1,
    n_chunk_size == base::round(n_chunk_size),
    msg = "`n_chunk_size` must be a whole number of at least 1."
  )

  assertthat::assert_that(
    base::is.character(path_schema),
    base::length(path_schema) == 1L,
    !base::is.na(path_schema),
    base::file.exists(path_schema),
    msg = "`path_schema` must be the path of an existing schema file."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  vec_schema_tables <-
    load_sql_statements(path_sql = path_schema) |>
    dplyr::filter(object_type == "table") |>
    dplyr::pull(object_name)

  vec_unknown_tables <-
    base::setdiff(base::names(list_tables), vec_schema_tables)

  if (
    base::length(vec_unknown_tables) > 0L
  ) {
    cli::cli_abort(
      c(
        "{.val {vec_unknown_tables}} {?is/are} not {?a table/tables} of the
        schema.",
        "i" = "Rows can only be written to the tables of the schema file."
      )
    )
  }

  vec_existing_objects <-
    DBI::dbListTables(conn = con) |>
    stringr::str_subset(pattern = "^sqlite_", negate = TRUE)

  if (
    base::length(vec_existing_objects) > 0L
  ) {
    cli::cli_abort(
      c(
        "The work file must be empty, but it holds
        {base::length(vec_existing_objects)} object{?s}.",
        "i" = "A build always loads a new work file."
      )
    )
  }

  if (
    base::file.exists(path_vacuum_into)
  ) {
    cli::cli_abort(
      "The new file of the build already exists; remove it first."
    )
  }

  time_start <-
    base::proc.time()[["elapsed"]]

  # 1. Tables and the view, with their keys and constraints
  build_database_schema(
    con = con,
    path_schema = path_schema,
    sel_objects = "tables"
  )

  time_schema <-
    base::proc.time()[["elapsed"]]

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform("Created the tables of the schema.")
  }

  # 2. Load settings
  purrr::iwalk(
    .x = list_pragmas_load,
    .f = ~ DBI::dbExecute(
      conn = con,
      statement = stringr::str_c(
        "PRAGMA ", .y, " = ", base::format(.x, scientific = FALSE)
      )
    )
  )

  validate_database_pragmas(
    con = con,
    list_pragmas = list_pragmas_load
  )

  time_pragmas_load <-
    base::proc.time()[["elapsed"]]

  # 3. Rows, table by table in schema order
  data_tables <-
    vec_schema_tables |>
    purrr::map(
      .f = ~ {
        name_table <- .x

        time_table_start <-
          base::proc.time()[["elapsed"]]

        res_table <-
          if (
            name_table %in% base::names(list_tables)
          ) {
            save_database_table(
              con = con,
              data_table = purrr::chuck(list_tables, name_table),
              name_table = name_table,
              n_chunk_size = n_chunk_size,
              verbose = verbose
            )
          } else {
            tibble::tibble(
              table_name = name_table,
              n_rows = 0L,
              n_chunks = 0L
            )
          }

        dplyr::mutate(
          res_table,
          seconds = base::proc.time()[["elapsed"]] - time_table_start
        )
      }
    ) |>
    purrr::list_rbind()

  time_tables <-
    base::proc.time()[["elapsed"]]

  # 4. Secondary indexes, after the rows
  build_database_schema(
    con = con,
    path_schema = path_schema,
    sel_objects = "indexes"
  )

  time_indexes <-
    base::proc.time()[["elapsed"]]

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform("Created the indexes.")
  }

  # 5. Statistics for the query planner
  DBI::dbExecute(
    conn = con,
    statement = "ANALYZE"
  )

  time_analyze <-
    base::proc.time()[["elapsed"]]

  # 6. Safe settings, checked before the copy
  purrr::iwalk(
    .x = list_pragmas_final,
    .f = ~ DBI::dbExecute(
      conn = con,
      statement = stringr::str_c(
        "PRAGMA ", .y, " = ", base::format(.x, scientific = FALSE)
      )
    )
  )

  validate_database_pragmas(
    con = con,
    list_pragmas = list_pragmas_final
  )

  time_pragmas_final <-
    base::proc.time()[["elapsed"]]

  # 7. A compact copy with the statistics; the work file stays as it is
  DBI::dbExecute(
    conn = con,
    statement = "VACUUM INTO ?",
    params = base::list(path_vacuum_into)
  )

  time_vacuum_into <-
    base::proc.time()[["elapsed"]]

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform("Ran ANALYZE and copied the work file with VACUUM INTO.")
  }

  vec_times <-
    c(
      time_start, time_schema, time_pragmas_load, time_tables, time_indexes,
      time_analyze, time_pragmas_final, time_vacuum_into
    )

  data_steps <-
    tibble::tibble(
      step = c(
        "schema", "pragmas_load", "tables", "indexes", "analyze",
        "pragmas_final", "vacuum_into"
      ),
      seconds = base::diff(vec_times)
    )

  res <-
    base::list(
      data_tables = data_tables,
      data_steps = data_steps
    )

  return(res)
}
