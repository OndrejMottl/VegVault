#' @title Load the column names and types of a database table
#' @description
#' Read the column names of one table of a built VegVault database and the
#' R class each column has when the table is read, for the column-name
#' files of the flat-file export.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param table_name
#' Character scalar. Name of the table; letters, digits and underscores
#' only.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble with one row per column, in table order, and the character
#' columns `table_name`, `column_name` and `data_type` (the first R class
#' of the column, e.g. `"integer"`, `"numeric"` or `"character"`).
#' @details
#' Reads no rows: the types come from a query with `LIMIT 0` through a
#' read-only connection (`run_with_database()`), so they follow the column
#' types declared in the schema.
#' @examples
#' \dontrun{
#' data_column_types <-
#'   load_table_column_types(
#'     path_database = path_database,
#'     table_name = "Datasets",
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_table_column_types <- function(
  path_database,
  table_name,
  list_build_manifest
) {
  validate_database_source(
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

  data_empty <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT * FROM [", table_name, "] LIMIT 0"
      ),
      flag_read_only = TRUE
    )

  vec_data_types <-
    data_empty |>
    purrr::map_chr(.f = ~ base::class(.x)[1]) |>
    base::unname()

  res <-
    tibble::tibble(
      table_name = table_name,
      column_name = base::names(data_empty),
      data_type = vec_data_types
    )

  return(res)
}
