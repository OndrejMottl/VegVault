get_db_table_data_types <- function(conn, table_name) {
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
