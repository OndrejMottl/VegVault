# This function copies a data frame to a table in a database if the data frame 
#   is not already in the table.
add_to_db <- function(
    conn,
    data,
    table_name,
    append = TRUE) {
  if (
    dplyr::tbl(conn, table_name) %>%
      dplyr::collect() %>%
      dplyr::bind_rows(
        data
      ) %>%
      test_unique_row_in_table()
  ) {
    dplyr::copy_to(
      conn,
      data,
      name = table_name,
      append = append
    )
  }
}