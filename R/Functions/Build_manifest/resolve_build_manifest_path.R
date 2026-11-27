#' @title Resolve the path of the build manifest of a database
#' @description
#' Return the path of the build manifest that belongs to a VegVault
#' database: a YAML file in the same folder, named after the database.
#' @param path_database
#' Character scalar. Path of the SQLite database file.
#' @return
#' Character scalar. The manifest path, `<folder>/<database name without
#' extension>_build_manifest.yml`, with forward slashes.
#' @details
#' Keeping the manifest next to its database gives every build (full,
#' regional subset, release) its own manifest. Neither file needs to exist.
#' @examples
#' \dontrun{
#' path_manifest <-
#'   resolve_build_manifest_path(
#'     path_database = resolve_database_path()
#'   )
#' }
resolve_build_manifest_path <- function(path_database) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::nzchar(path_database),
    msg = "`path_database` must be a non-empty character scalar."
  )

  path_database_slashed <-
    stringr::str_replace_all(
      string = path_database,
      pattern = stringr::fixed("\\"),
      replacement = "/"
    )

  res <-
    stringr::str_c(
      tools::file_path_sans_ext(path_database_slashed),
      "_build_manifest.yml"
    )

  return(res)
}
