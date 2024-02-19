add_dataset_source_type <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "dataset_source_type"
      )
    ),
    msg = "data_source must have columns 'dataset_source_type'"
  )

  dataset_source_type <-
    data_source %>%
    dplyr::distinct(dataset_source_type)


  data_source_type_id_db <-
    dplyr::tbl(con, "DatasetSourceTypeID") %>%
    dplyr::distinct(dataset_source_type) %>%
    dplyr::collect() %>%
    purrr::chuck("dataset_source_type")

  dataset_source_type_unique <-
    dataset_source_type %>%
    dplyr::filter(
      !dataset_source_type %in% data_source_type_id_db
    )

  add_to_db(
    conn = con,
    data = dataset_source_type_unique,
    table_name = "DatasetSourceTypeID"
  )

  dataset_source_type_db <-
    dplyr::tbl(con, "DatasetSourceTypeID") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(dataset_source_type),
      by = dplyr::join_by(dataset_source_type)
    )

  return(dataset_source_type_db)
}
