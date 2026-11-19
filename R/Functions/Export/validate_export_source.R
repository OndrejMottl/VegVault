#' @title Validate that a database is the one its build manifest describes
#' @description
#' Check that the database an export step reads is the database of the
#' build manifest passed along with it, so that the export only reads a
#' verified build.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database, as returned by
#' `load_build_manifest()`.
#' @return
#' `path_database`, unchanged and invisibly.
#' @details
#' Aborts when the file name of `path_database` differs from
#' `database: file_name` of the manifest, or when the manifest has no such
#' field. The full check of size and modification time is done once by
#' `load_build_manifest()`; the export steps take the manifest as an
#' argument so that `{targets}` reruns them when a new build writes a new
#' manifest. Messages never contain the database path.
#' @examples
#' \dontrun{
#' validate_export_source(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
validate_export_source <- function(
  path_database,
  list_build_manifest
) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::nzchar(path_database),
    msg = "`path_database` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.list(list_build_manifest),
    msg = stringr::str_c(
      "`list_build_manifest` must be the list returned by ",
      "load_build_manifest()."
    )
  )

  file_name_manifest <-
    purrr::pluck(list_build_manifest, "database", "file_name")

  if (
    !base::is.character(file_name_manifest) ||
      base::length(file_name_manifest) != 1L
  ) {
    cli::cli_abort(
      "The build manifest has no {.field database: file_name}."
    )
  }

  # The message names no file, because database paths are private
  if (
    !base::identical(base::basename(path_database), file_name_manifest)
  ) {
    cli::cli_abort(
      "The database to export is not the database of the build manifest."
    )
  }

  res <- path_database

  return(invisible(res))
}
