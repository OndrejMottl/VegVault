#' @title Validate that a table has no duplicated rows
#' @description
#' Check, before rows are written to the database, that no two rows of a
#' table are equal in their non-integer columns.
#' @param data_source
#' A data frame.
#' @return
#' `TRUE` when the rows are unique.
#' @details
#' Integer columns (database IDs) are ignored, so two rows that differ
#' only in an ID count as duplicates. Aborts when the number of distinct
#' rows differs from the number of rows; the message names the object
#' passed as `data_source`.
#' @examples
#' \dontrun{
#' validate_unique_rows(data_source = data_taxa)
#' }
validate_unique_rows <- function(data_source) {
  n_rows_raw <- nrow(data_source)

  n_row_distinc <-
    data_source %>%
    dplyr::select(
      dplyr::where(
        ~ !is.integer(.x)
      )
    ) %>%
    dplyr::distinct() %>%
    nrow()

  assertthat::assert_that(
    n_rows_raw == n_row_distinc,
    msg = paste0(
      "The number of unique rows in the table ",
      deparse(substitute(data_source)),
      " does not match the number of rows in the table "
    )
  )
}
