#' @title Load the table names of a VegVault database
#' @description
#' List the tables of a built VegVault database, read-only, as the units of
#' the flat-file export.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' Character vector of table names, sorted alphabetically. SQLite's
#' internal tables (`sqlite_*`) are not included.
#' @details
#' Opens the database read-only through `run_with_database()`. Aborts when
#' the database is not the one of the manifest or does not exist.
#' @examples
#' \dontrun{
#' vec_table_names <-
#'   load_database_table_names(
#'     path_database = path_database,
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_database_table_names <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  vec_table_names_all <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbListTables,
      flag_read_only = TRUE
    )

  # Radix sorting gives the same order in every locale
  res <-
    vec_table_names_all |>
    purrr::discard(.p = ~ stringr::str_starts(.x, "sqlite_")) |>
    base::sort(method = "radix")

  return(res)
}
