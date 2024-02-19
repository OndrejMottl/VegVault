add_dataset_source_type_with_reference <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "dataset_source_type",
        "data_source_type_reference"
      )
    ),
    msg = "data_source must have columns 'dataset_source_type' and 'data_source_type_reference'"
  )

  dataset_source_type_referecne_db <-
    add_dataset_source_type_reference(
      data_source = data_source,
      con = con
    )

  dataset_source_type <-
    data_source %>%
    dplyr::distinct(dataset_source_type, data_source_type_reference) %>%
    dplyr::inner_join(
      dataset_source_type_referecne_db,
      by = dplyr::join_by(data_source_type_reference == reference_detail)
    ) %>%
    dplyr::select(
      dataset_source_type,
      reference_id
    ) %>%
    dplyr::rename(data_source_type_reference = reference_id)

  data_source_type_id_db <-
    dplyr::tbl(con, "References") %>%
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
