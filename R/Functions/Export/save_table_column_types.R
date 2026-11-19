#' @title Save the column names and types of a table as a CSV file
#' @description
#' Write the column names and types of one table to
#' `<dir_export>/Column_names/<table_name>_columns.csv`, next to the CSV
#' files of the flat-file export.
#' @param data_column_types
#' A tibble for one table, as returned by `load_table_column_types()`, with
#' the columns `table_name`, `column_name` and `data_type`.
#' @param dir_export
#' Character scalar. Folder of the flat-file export (see
#' `resolve_output_dir()`). The `Column_names` folder in it is created when
#' missing.
#' @return
#' Character scalar: the path of the CSV file, so that the function can be
#' the command of a `{targets}` target with `format = "file"`.
#' @details
#' The file has the columns `column_name` and `data_type`, one row per
#' column of the table. It is always written, replacing an existing file:
#' in the pipeline, `{targets}` decides when it is written again (see
#' `build_export_cue()`). Aborts when `data_column_types` holds no table or
#' more than one.
#' @examples
#' \dontrun{
#' path_csv <-
#'   save_table_column_types(
#'     data_column_types = data_column_types,
#'     dir_export = dir_export
#'   )
#' }
save_table_column_types <- function(
  data_column_types,
  dir_export
) {
  vec_columns_required <-
    c("table_name", "column_name", "data_type")

  assertthat::assert_that(
    base::is.data.frame(data_column_types),
    base::all(vec_columns_required %in% base::names(data_column_types)),
    msg = stringr::str_c(
      "`data_column_types` must have the columns `table_name`, ",
      "`column_name` and `data_type`."
    )
  )

  assertthat::assert_that(
    base::is.character(dir_export),
    base::length(dir_export) == 1L,
    !base::is.na(dir_export),
    base::nzchar(dir_export),
    msg = "`dir_export` must be a non-empty character scalar."
  )

  vec_table_names <-
    data_column_types |>
    dplyr::pull(table_name) |>
    base::unique()

  if (
    base::length(vec_table_names) != 1L
  ) {
    cli::cli_abort(
      "{.arg data_column_types} must describe exactly one table, not
      {base::length(vec_table_names)}."
    )
  }

  dir_column_names <-
    base::file.path(dir_export, "Column_names")

  path_csv <-
    base::file.path(
      dir_column_names,
      stringr::str_c(vec_table_names, "_columns.csv")
    )

  base::dir.create(
    path = dir_column_names,
    recursive = TRUE,
    showWarnings = FALSE
  )

  readr::write_csv(
    x = dplyr::select(data_column_types, column_name, data_type),
    file = path_csv
  )

  res <- path_csv

  return(res)
}
