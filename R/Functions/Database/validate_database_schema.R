#' @title Validate a database against its schema file
#' @description
#' Check that a SQLite database holds exactly the tables, views and
#' indexes of a schema file, each with the definition of that file, and
#' abort with a list of every difference otherwise.
#' @param con
#' A valid `DBI` connection to the SQLite database. It is only read, so a
#' read-only connection is enough.
#' @param path_schema
#' Character scalar. Path of the schema file. Default:
#' `Data/SQL/make_tables.sql` of the project.
#' @param flag_require_indexes
#' Logical scalar. If `TRUE` (default), every index of the schema file
#' must exist. If `FALSE`, indexes may be missing, which is the state
#' after the tables are loaded and before the indexes are created; an
#' index that exists must still match its definition.
#' @return
#' Invisibly, a tibble with one row per object of the schema file that
#' was checked, with the columns `object_type` (`"table"`, `"view"` or
#' `"index"`) and `object_name`.
#' @details
#' The reference is built by executing the schema file in a new
#' in-memory database. Both databases are then compared on
#' `sqlite_schema`: object type, name, table and SQL text (SQLite stores
#' the text of each `CREATE` statement, so any change of a column,
#' constraint or index shows up). Objects whose names start with
#' `sqlite_` (automatic indexes and statistics tables) are not compared.
#' Aborts when an object is missing, when the database has an object the
#' schema file does not define, or when a definition differs. The
#' messages name the objects, never the database path. The database is
#' not changed.
#' @seealso [build_database_schema()], [load_sql_statements()]
#' @examples
#' \dontrun{
#' run_with_database(
#'   path_database = path_database,
#'   fn = validate_database_schema,
#'   flag_read_only = TRUE
#' )
#' }
validate_database_schema <- function(
  con,
  path_schema = here::here("Data", "SQL", "make_tables.sql"),
  flag_require_indexes = TRUE
) {
  assertthat::assert_that(
    methods::is(con, "DBIConnection"),
    DBI::dbIsValid(con),
    msg = "`con` must be a valid DBI connection."
  )

  assertthat::assert_that(
    base::is.character(path_schema),
    base::length(path_schema) == 1L,
    !base::is.na(path_schema),
    base::file.exists(path_schema),
    msg = "`path_schema` must be the path of an existing SQL file."
  )

  assertthat::assert_that(
    assertthat::is.flag(flag_require_indexes),
    !base::is.na(flag_require_indexes),
    msg = "`flag_require_indexes` must be TRUE or FALSE."
  )

  data_statements <-
    load_sql_statements(path_sql = path_schema) |>
    dplyr::filter(object_type %in% c("table", "view", "index"))

  # The reference: the schema file executed in a new in-memory database
  con_reference <-
    DBI::dbConnect(drv = RSQLite::SQLite(), dbname = ":memory:")

  base::on.exit(
    DBI::dbDisconnect(conn = con_reference),
    add = TRUE
  )

  purrr::walk(
    .x = dplyr::pull(data_statements, statement),
    .f = ~ DBI::dbExecute(conn = con_reference, statement = .x)
  )

  # Names starting with `sqlite_` are reserved for SQLite's own objects
  sql_objects <-
    stringr::str_c(
      "SELECT type AS object_type, name AS object_name, tbl_name, sql ",
      "FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'"
    )

  data_reference <-
    DBI::dbGetQuery(conn = con_reference, statement = sql_objects) |>
    tibble::as_tibble()

  data_database <-
    DBI::dbGetQuery(conn = con, statement = sql_objects) |>
    tibble::as_tibble()

  vec_types_required <-
    if (
      base::isTRUE(flag_require_indexes)
    ) {
      c("table", "view", "index")
    } else {
      c("table", "view")
    }

  vec_missing <-
    data_reference |>
    dplyr::filter(object_type %in% vec_types_required) |>
    dplyr::anti_join(
      y = data_database,
      by = dplyr::join_by(object_type, object_name)
    ) |>
    dplyr::pull(object_name)

  vec_unexpected <-
    data_database |>
    dplyr::anti_join(
      y = data_reference,
      by = dplyr::join_by(object_type, object_name)
    ) |>
    dplyr::pull(object_name)

  vec_changed <-
    data_reference |>
    dplyr::inner_join(
      y = data_database,
      by = dplyr::join_by(object_type, object_name),
      suffix = c("_reference", "_database"),
      relationship = "one-to-one"
    ) |>
    dplyr::filter(
      tbl_name_reference != tbl_name_database |
        !purrr::map2_lgl(
          .x = sql_reference,
          .y = sql_database,
          .f = base::identical
        )
    ) |>
    dplyr::pull(object_name)

  if (
    base::length(c(vec_missing, vec_unexpected, vec_changed)) > 0L
  ) {
    vec_problems <-
      c(
        "x" = if (
          base::length(vec_missing) > 0L
        ) {
          "Missing: {.val {vec_missing}}."
        },
        "x" = if (
          base::length(vec_unexpected) > 0L
        ) {
          "Not defined in the schema file: {.val {vec_unexpected}}."
        },
        "x" = if (
          base::length(vec_changed) > 0L
        ) {
          "Defined differently from the schema file: {.val {vec_changed}}."
        }
      )

    cli::cli_abort(
      c(
        "The database does not match its schema file.",
        vec_problems
      )
    )
  }

  res <-
    data_statements |>
    dplyr::filter(object_name %in% dplyr::pull(data_database, object_name)) |>
    dplyr::select(object_type, object_name)

  return(base::invisible(res))
}
