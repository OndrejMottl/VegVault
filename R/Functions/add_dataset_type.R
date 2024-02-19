add_dataset_type <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "dataset_type"),
    msg = "data_source must have column 'dataset_type'"
  )

  dataset_type_db <-
    dplyr::tbl(con, "DatasetTypeID") %>%
    dplyr::distinct(dataset_type) %>%
    dplyr::collect() %>%
    purrr::pluck("dataset_type")

  dataset_type_id <-
    data_source %>%
    dplyr::distinct(dataset_type) %>%
    tidyr::drop_na() %>%
    dplyr::filter(
      !dataset_type %in% dataset_type_db
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
