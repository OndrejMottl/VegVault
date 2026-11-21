save_data_source <- function(data_source, con, mandatory = FALSE) {
  data_source_id_db <-
    save_data_source_id(data_source, con)

  save_data_source_reference(
    data_source = data_source,
    data_source_id = data_source_id_db,
    con = con,
    mandatory = mandatory
  )

  return(data_source_id_db)
}
