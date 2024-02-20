add_dataset_source_type <- function(data_source, con) {
  data_dataset_source_type_db <-
    add_dataset_source_type_id(
      data_source = data_source,
      con = con
    )

  add_dataset_source_type_reference(
    data_source = data_source,
    data_source_type_id = data_dataset_source_type_db,
    con = con
  )

  return(data_dataset_source_type_db)
}
