#' @title Resolve the paths of the files of a database build
#' @description
#' Derive, from the path of the database being built, the work file that
#' the rows are loaded into and the new file that `VACUUM INTO` writes
#' before it replaces the database.
#' @param path_database
#' Character scalar. Path of the database being built, ending in
#' `.sqlite`.
#' @return
#' A named list of two character scalars in the folder of
#' `path_database`: `path_work` (`<name>_work.sqlite`) and `path_new`
#' (`<name>_new.sqlite`).
#' @details
#' Both files sit next to the database, on the drive chosen for it.
#' Aborts when `path_database` does not end in `.sqlite` (in any case) or
#' already names a work or new file, so a build can never load into or
#' replace its own database. Error messages never print the path, because
#' database paths are private.
#' @seealso [save_vegvault_database()]
#' @examples
#' \dontrun{
#' list_paths <-
#'   resolve_database_build_paths(
#'     path_database = resolve_database_path()
#'   )
#' }
resolve_database_build_paths <- function(path_database) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::nzchar(path_database),
    msg = "`path_database` must be a non-empty character scalar."
  )

  regex_extension <-
    stringr::regex("\\.sqlite$", ignore_case = TRUE)

  if (
    !stringr::str_detect(
      string = path_database,
      pattern = regex_extension
    )
  ) {
    cli::cli_abort(
      "The database file name must end in {.file .sqlite}."
    )
  }

  name_extension <-
    stringr::str_extract(
      string = path_database,
      pattern = regex_extension
    )

  path_stem <-
    stringr::str_remove(
      string = path_database,
      pattern = regex_extension
    )

  if (
    stringr::str_detect(
      string = base::basename(path_stem),
      pattern = "_(work|new)$"
    )
  ) {
    cli::cli_abort(
      c(
        "The database file name ends in {.val _work} or {.val _new}.",
        "i" = "These endings name the work and new files of a build."
      )
    )
  }

  # The suffixes are added to the path as given, so its separators stay
  res <-
    base::list(
      path_work = stringr::str_c(path_stem, "_work", name_extension),
      path_new = stringr::str_c(path_stem, "_new", name_extension)
    )

  return(res)
}
