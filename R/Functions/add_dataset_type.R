add_dataset_type <- function(data_source, con) {
  dataset_type_id <-
    data_source %>%
    dplyr::distinct(dataset_type) %>%
    tidyr::drop_na() %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetTypeID") %>%
        dplyr::select(dataset_type) %>%
        dplyr::collect(),
      by = dplyr::join_by(dataset_type)
    )

  add_to_db(
    conn = con,
    data = dataset_type_id,
    table_name = "DatasetTypeID"
  )

  dataset_type_id_db <-
    dplyr::tbl(con, "DatasetTypeID") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(dataset_type),
      by = dplyr::join_by(dataset_type)
    )
  return(dataset_type_id_db)
}
