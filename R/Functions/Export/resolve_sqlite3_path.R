#' @title Resolve the path of the sqlite3 command-line tool
#' @description
#' Return the path of the `sqlite3` executable that exports database tables
#' to CSV, and stop with installation advice when it is missing.
#' @param path_candidate
#' Character scalar. The path to check. Default: `sqlite3` as found on the
#' `PATH` (`Sys.which()`), which is an empty string when it is missing.
#' @return
#' Character scalar. The absolute path of the executable, with forward
#' slashes.
#' @details
#' Aborts when `path_candidate` is empty or does not name an existing file.
#' On Windows, install the tool with
#' `winget install --exact --id SQLite.SQLite` and open a new terminal.
#' @examples
#' \dontrun{
#' path_sqlite3 <- resolve_sqlite3_path()
#' }
resolve_sqlite3_path <- function(
  path_candidate = base::Sys.which("sqlite3")
) {
  assertthat::assert_that(
    base::is.character(path_candidate),
    base::length(path_candidate) == 1L,
    !base::is.na(path_candidate),
    msg = "`path_candidate` must be a character scalar."
  )

  # Sys.which() names its result after the command
  path_unnamed <-
    base::unname(path_candidate)

  if (
    !base::nzchar(path_unnamed) ||
      !base::file.exists(path_unnamed) ||
      base::dir.exists(path_unnamed)
  ) {
    cli::cli_abort(
      c(
        "The sqlite3 command-line tool was not found.",
        "i" = "On Windows, install it with
        {.code winget install --exact --id SQLite.SQLite} and open a new
        terminal."
      )
    )
  }

  res <-
    base::normalizePath(path_unnamed, winslash = "/")

  return(res)
}
