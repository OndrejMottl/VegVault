#' @title Load the column names and types of a database table
#' @description
#' Read the columns of one table of an open database connection with their
#' declared SQLite types, for the column tables of the website.
#' @param conn
#' An open DBI connection to a SQLite database.
#' @param table_name
#' Character scalar. Name of the table.
#' @return
#' A data frame with the columns `column_name` and `data_type`, one row
#' per column of the table, in table order.
#' @examples
#' \dontrun{
#' load_db_table_data_types(conn = con, table_name = "Datasets")
#' }
load_db_table_data_types <- function(conn, table_name) {
  query <-
    paste(
      "PRAGMA table_info(", table_name, ");"
    )

  res <-
    DBI::dbGetQuery(conn, query)

  res %>%
    dplyr::mutate(
      note = ifelse(pk == 1, "Primary key", ""),
      name = as.character(name),
      type = as.character(type)
    ) %>%
    dplyr::select(
      column_name = "name",
      data_type = "type"
    ) %>%
    return()
}
