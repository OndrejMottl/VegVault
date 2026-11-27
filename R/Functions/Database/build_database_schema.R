#' @title Build the VegVault schema in a database
#' @description
#' Create the tables, the view and the indexes of the schema file in a
#' SQLite database, one statement at a time, and check the result with
#' `validate_database_schema()`. Any failed statement stops the build.
#' @param con
#' A valid read-write `DBI` connection to the SQLite database, normally a
#' new, empty file opened with `run_with_database()`.
#' @param path_schema
#' Character scalar. Path of the schema file. Default:
#' `Data/SQL/make_tables.sql` of the project.
#' @param sel_objects
#' Character scalar, one of:
#' \itemize{
#'   \item `"all"` (default): tables, view and indexes;
#'   \item `"tables"`: the tables and the view only, for a bulk load that
#'     creates the indexes afterwards;
#'   \item `"indexes"`: the indexes only, after such a load.
#' }
#' @return
#' Invisibly, a tibble with one row per executed statement, in file
#' order: `statement_id`, `object_type` and `object_name` (as returned by
#' `load_sql_statements()`).
#' @details
#' The schema file may only create tables, views and indexes; any other
#' statement aborts before anything is executed. Constraints declared in
#' `CREATE TABLE` (primary keys, `UNIQUE`, `NOT NULL`, `CHECK`, foreign
#' keys) belong to the tables and are active during a load; every
#' `CREATE INDEX` statement is a secondary index created by
#' `sel_objects = "indexes"`.
#' All selected statements run in one transaction. When one fails, the
#' error names the statement number and the object, and the transaction
#' is rolled back, so the database holds none of the selected objects.
#' Afterwards the database is checked with `validate_database_schema()`,
#' requiring the indexes unless `sel_objects = "tables"`.
#' The function never opens or closes a connection; use it inside
#' `run_with_database()`, which closes the connection on success and on
#' error.
#' @seealso [validate_database_schema()], [load_sql_statements()],
#' [run_with_database()]
#' @examples
#' \dontrun{
#' run_with_database(
#'   path_database = base::file.path(base::tempdir(), "schema.sqlite"),
#'   fn = build_database_schema
#' )
#' }
build_database_schema <- function(
  con,
  path_schema = here::here("Data", "SQL", "make_tables.sql"),
  sel_objects = "all"
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
    base::is.character(sel_objects),
    base::length(sel_objects) == 1L,
    !base::is.na(sel_objects),
    sel_objects %in% c("all", "tables", "indexes"),
    msg = "`sel_objects` must be one of \"all\", \"tables\" or \"indexes\"."
  )

  data_statements <-
    load_sql_statements(path_sql = path_schema)

  vec_id_other <-
    data_statements |>
    dplyr::filter(object_type == "other") |>
    dplyr::pull(statement_id)

  if (
    base::length(vec_id_other) > 0L
  ) {
    cli::cli_abort(
      c(
        "The schema file may only create tables, views and indexes.",
        "x" = "Statement{?s} {vec_id_other} {?does/do} not."
      )
    )
  }

  vec_types_selected <-
    base::switch(
      sel_objects,
      all = c("table", "view", "index"),
      tables = c("table", "view"),
      indexes = "index"
    )

  data_selected <-
    dplyr::filter(data_statements, object_type %in% vec_types_selected)

  # One transaction, so that a failed statement leaves none of the selected
  #   objects behind
  DBI::dbWithTransaction(
    conn = con,
    code = purrr::walk(
      .x = base::seq_len(base::nrow(data_selected)),
      .f = ~ {
        data_statement <-
          dplyr::slice(data_selected, .x)

        base::tryCatch(
          DBI::dbExecute(
            conn = con,
            statement = dplyr::pull(data_statement, statement)
          ),
          error = function(cnd) {
            cli::cli_abort(
              "Schema statement {dplyr::pull(data_statement, statement_id)}
              ({dplyr::pull(data_statement, object_type)}
              {.val {dplyr::pull(data_statement, object_name)}}) failed.",
              parent = cnd
            )
          }
        )
      }
    )
  )

  validate_database_schema(
    con = con,
    path_schema = path_schema,
    flag_require_indexes = sel_objects != "tables"
  )

  res <-
    dplyr::select(data_selected, statement_id, object_type, object_name)

  return(base::invisible(res))
}
