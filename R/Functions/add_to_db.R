# This function copies a data frame to a table in a database if the data frame
#   is not already in the table.
add_to_db <- function(
    conn,
    data,
    table_name,
    overwrite_test = FALSE,
    append = TRUE) {
  is_valid <- FALSE

  if (
    isTRUE(overwrite_test)
  ) {
    is_valid <- TRUE
  } else {
    is_valid <-
      dplyr::tbl(conn, table_name) %>%
      dplyr::collect() %>%
      dplyr::bind_rows(
        data
      ) %>%
      test_unique_row_in_table()
  }

  if (
    isTRUE(is_valid)
  ) {
    message(
      paste("adding", nrow(data), "rows to", table_name, "table")
    )

    dplyr::copy_to(
      conn,
      data,
      name = table_name,
      append = append
    )
  }
}
