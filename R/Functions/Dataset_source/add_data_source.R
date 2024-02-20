add_data_source <- function(data_source, con) {

  data_source_id_db <-
    add_data_source_id(data_source, con)

  add_data_source_referecne(
    data_source = data_source,
    data_source_id = data_source_id_db,
    con = con
  )

  return(data_source_id_db)
}
