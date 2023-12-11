# test the distinct nuber of rows, exlcuding all integer columns
test_unique_row_in_table <- function(data_source) {
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
      "The number of uniqu rows in the table ",
      deparse(substitute(data_source)),
      " does not match the number of rows in the table "
    )
  )
}