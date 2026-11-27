#' @title Run a function on a VegVault database connection
#' @description
#' Open a connection to a VegVault SQLite database, pass it to a function,
#' and always disconnect afterwards, whether the function succeeds or
#' fails.
#' @param path_database
#' Character scalar. Path of the SQLite database file, typically from
#' `resolve_database_path()`.
#' @param fn
#' A function, or a `purrr`-style formula, whose first argument receives
#' the open `DBI` connection.
#' @param ...
#' Further arguments passed on to `fn`.
#' @param flag_read_only
#' Logical scalar. If `TRUE`, the database is opened read-only
#' (`RSQLite::SQLITE_RO`), so that no statement can change it, and the
#' file must already exist. If `FALSE` (default), it is opened for reading
#' and writing and is created when missing.
#' @return
#' The value returned by `fn`.
#' @details
#' The connection is closed on exit in every case, including when `fn`
#' throws an error, which is passed on to the caller. Error messages
#' never contain the database path, because database paths are private.
#' A connection must not be returned by `fn` or kept elsewhere, as it is
#' no longer valid once this function returns.
#' @examples
#' \dontrun{
#' vec_tables <-
#'   run_with_database(
#'     path_database = resolve_database_path(),
#'     fn = DBI::dbListTables,
#'     flag_read_only = TRUE
#'   )
#' }
run_with_database <- function(
  path_database,
  fn,
  ...,
  flag_read_only = FALSE
) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::nzchar(path_database),
    msg = "`path_database` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.function(fn) || rlang::is_formula(fn),
    msg = "`fn` must be a function or a formula."
  )

  assertthat::assert_that(
    assertthat::is.flag(flag_read_only),
    !base::is.na(flag_read_only),
    msg = "`flag_read_only` must be TRUE or FALSE."
  )

  # SQLite would create an empty file for a missing read-write path, but
  #   a read-only connection can only describe an existing database
  if (
    base::isTRUE(flag_read_only) &&
      !base::file.exists(path_database)
  ) {
    cli::cli_abort(
      c(
        "The database file does not exist, so it cannot be opened
        read-only.",
        "i" = "Check the database path in {.file secrets.yaml}."
      )
    )
  }

  fn_task <-
    rlang::as_function(fn)

  flags_open <-
    if (
      base::isTRUE(flag_read_only)
    ) {
      RSQLite::SQLITE_RO
    } else {
      RSQLite::SQLITE_RWC
    }

  con <-
    DBI::dbConnect(
      drv = RSQLite::SQLite(),
      dbname = path_database,
      flags = flags_open
    )

  # Registered before the task runs, so the connection is closed on
  #   success and on error alike
  base::on.exit(
    DBI::dbDisconnect(conn = con),
    add = TRUE
  )

  res <-
    fn_task(con, ...)

  return(res)
}
