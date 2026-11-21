#' @title Save the changes of the counts against v1.0.0
#' @description
#' Write the table of count changes against v1.0.0 next to the validation
#' report, as a CSV file named after the build.
#' @param data_deltas
#' A tibble of changes, as returned by `compute_v1_count_deltas()`.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `build_validation_id()`).
#' @param dir_output
#' Character scalar. The folder of the validation report; created when
#' missing.
#' @return
#' Character scalar. The path of the written file,
#' `validation_v1_deltas_<build id>.csv`.
#' @details
#' Missing values are written as empty fields. An existing file of the
#' same build is replaced, as the report of that build is. Aborts when
#' `data_deltas` lacks a column of `compute_v1_count_deltas()`.
#' @seealso [save_validation_report()], [build_validation_id()]
#' @examples
#' \dontrun{
#' save_v1_count_deltas(
#'   data_deltas = data_v1_deltas,
#'   list_build_manifest = list_build_manifest,
#'   dir_output = dir_validation
#' )
#' }
save_v1_count_deltas <- function(
  data_deltas,
  list_build_manifest,
  dir_output
) {
  vec_columns <-
    c(
      "metric", "scope", "n_v1", "n_v2", "delta", "relative_change",
      "status", "expected_reason", "note"
    )

  assertthat::assert_that(
    base::is.data.frame(data_deltas),
    base::all(vec_columns %in% base::names(data_deltas)),
    msg = "'data_deltas' must be a table of compute_v1_count_deltas()."
  )

  assertthat::assert_that(
    assertthat::is.string(dir_output),
    msg = "'dir_output' must be a character scalar."
  )

  base::dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)

  res <-
    base::file.path(
      dir_output,
      stringr::str_c(
        "validation_v1_deltas_",
        build_validation_id(list_build_manifest = list_build_manifest),
        ".csv"
      )
    )

  readr::write_csv(
    dplyr::select(data_deltas, dplyr::all_of(vec_columns)),
    res,
    na = ""
  )

  return(res)
}
