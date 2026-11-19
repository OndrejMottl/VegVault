#' @title Save a database table as a CSV file
#' @description
#' Export one table of a built VegVault database to
#' `<dir_export>/<table_name>.csv` with the `sqlite3` command-line tool,
#' which streams the rows without loading the table into R.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param table_name
#' Character scalar. Name of the table; letters, digits and underscores
#' only.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_export_source()`).
#' @param dir_export
#' Character scalar. Folder of the flat-file export (see
#' `resolve_export_dir()`); created when missing.
#' @param path_sqlite3
#' Character scalar. Path of the `sqlite3` executable (see
#' `resolve_sqlite3_path()`).
#' @return
#' Character scalar: the path of the CSV file, so that the function can be
#' the command of a `{targets}` target with `format = "file"`.
#' @details
#' The CSV has a header row, comma-separated values and rows ending in CRLF
#' (`.mode csv` of `sqlite3`, as in the v1 export); `NULL` becomes an empty
#' field. An empty table gives an empty file, because `sqlite3` writes no
#' header without rows. `sqlite3` opens the database with `-readonly`.
#' The file is always written: in the pipeline, `{targets}` decides when a
#' table is exported again (see `build_export_cue()`). The rows go to a
#' temporary file in `dir_export` that replaces the CSV only when `sqlite3`
#' exits with status 0, so a failed export leaves an existing CSV as it
#' was and never leaves a partial one. Aborts on a non-zero exit status
#' with the first line of the `sqlite3` error, in which the database path
#' is replaced by `<database>`; messages never contain the database path.
#' @examples
#' \dontrun{
#' path_csv <-
#'   save_table_csv(
#'     path_database = path_database,
#'     table_name = "Datasets",
#'     list_build_manifest = list_build_manifest,
#'     dir_export = resolve_export_dir(),
#'     path_sqlite3 = resolve_sqlite3_path()
#'   )
#' }
save_table_csv <- function(
  path_database,
  table_name,
  list_build_manifest,
  dir_export,
  path_sqlite3
) {
  validate_export_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  # The name goes into SQL, so only plain identifiers are accepted
  assertthat::assert_that(
    base::is.character(table_name),
    base::length(table_name) == 1L,
    base::isTRUE(stringr::str_detect(table_name, "^[A-Za-z0-9_]+$")),
    msg = "`table_name` must contain only letters, digits and underscores."
  )

  assertthat::assert_that(
    base::is.character(dir_export),
    base::length(dir_export) == 1L,
    !base::is.na(dir_export),
    base::nzchar(dir_export),
    base::is.character(path_sqlite3),
    base::length(path_sqlite3) == 1L,
    !base::is.na(path_sqlite3),
    base::nzchar(path_sqlite3),
    msg = "`dir_export` and `path_sqlite3` must be non-empty text values."
  )

  # The message omits the path, because database paths are private
  if (
    !base::file.exists(path_database)
  ) {
    cli::cli_abort("The database file does not exist.")
  }

  path_csv <-
    base::file.path(dir_export, stringr::str_c(table_name, ".csv"))

  base::dir.create(
    path = dir_export,
    recursive = TRUE,
    showWarnings = FALSE
  )

  # Rows go to a temporary file first, so a failed export never replaces
  #   or truncates the CSV
  path_partial <-
    stringr::str_c(path_csv, ".partial")

  path_stderr <-
    base::tempfile(fileext = ".txt")

  # system2() warns on a non-zero status; the status is checked below
  status_exit <-
    base::suppressWarnings(
      base::system2(
        command = path_sqlite3,
        args = c(
          "-readonly",
          "-header",
          "-cmd",
          base::shQuote(".mode csv"),
          base::shQuote(path_database),
          base::shQuote(
            stringr::str_c("SELECT * FROM [", table_name, "];")
          )
        ),
        stdout = path_partial,
        stderr = path_stderr
      )
    )

  if (
    !base::identical(base::as.integer(status_exit), 0L)
  ) {
    base::unlink(path_partial)

    # 127 is the status of a command that could not be started
    if (
      base::identical(base::as.integer(status_exit), 127L)
    ) {
      base::unlink(path_stderr)

      cli::cli_abort(
        c(
          "sqlite3 could not be started (exit status 127).",
          "i" = "Check {.fn resolve_sqlite3_path} and the {.envvar PATH}."
        )
      )
    }

    vec_lines_stderr <-
      if (
        base::file.exists(path_stderr)
      ) {
        base::readLines(con = path_stderr, warn = FALSE)
      } else {
        base::character(0)
      }

    base::unlink(path_stderr)

    # The first message line names the reason; the database path in it is
    #   replaced, because database paths are private
    text_reason <-
      vec_lines_stderr |>
      purrr::discard(.p = ~ !base::nzchar(stringr::str_trim(.x))) |>
      purrr::pluck(1, .default = "no message") |>
      stringr::str_replace_all(
        pattern = stringr::fixed(path_database),
        replacement = "<database>"
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed(
          base::normalizePath(path_database, winslash = "\\")
        ),
        replacement = "<database>"
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed(
          base::normalizePath(path_database, winslash = "/")
        ),
        replacement = "<database>"
      )

    cli::cli_abort(
      c(
        "sqlite3 could not export table {.val {table_name}} (exit status
        {status_exit}).",
        "x" = "{text_reason}",
        "i" = "The CSV file was not changed."
      )
    )
  }

  base::unlink(path_stderr)

  # file.rename() warns with the paths when it fails; the result is
  #   checked below
  flag_renamed <-
    base::suppressWarnings(
      base::file.rename(from = path_partial, to = path_csv)
    )

  if (
    !base::isTRUE(flag_renamed)
  ) {
    base::unlink(path_partial)

    cli::cli_abort(
      "The exported rows of table {.val {table_name}} could not replace
      {.file {base::basename(path_csv)}}."
    )
  }

  res <- path_csv

  return(res)
}
