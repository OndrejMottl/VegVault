#' @title Load the table names of a VegVault database
#' @description
#' List the tables of a built VegVault database, read-only, as the units of
#' the flat-file export. Views are not tables and are left out.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' Character vector of table names, sorted alphabetically. SQLite's
#' internal tables (`sqlite_*`) and views are not included.
#' @details
#' Reads the objects of type `table` from `sqlite_master`, unlike
#' `DBI::dbListTables()`, which also returns views. A view holds no rows of
#' its own: the view `AbioticDataReference` of the 2.0.0 schema joins the
#' position tables `SamplePosition` and `PositionLink` to one row per
#' sample and gridpoint, about two billion rows, so the export writes the
#' position tables instead. Opens the database read-only through
#' `run_with_database()`. Aborts when the database is not the one of the
#' manifest or does not exist.
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

  # DBI::dbListTables() would also return views
  data_tables <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT name FROM sqlite_master WHERE type = 'table'",
      flag_read_only = TRUE
    )

  # Radix sorting gives the same order in every locale
  res <-
    data_tables |>
    dplyr::pull(name) |>
    purrr::discard(.p = ~ stringr::str_starts(.x, "sqlite_")) |>
    base::sort(method = "radix")

  return(res)
}
