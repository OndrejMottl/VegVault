add_dataset_reference <- function(data_source, dataset_id, con) {
  dataset_reference_db <-
    add_dataset_reference_id(
      data_source = data_source,
      con = con
    )
  dataset_reference_lookup <-
    data_source %>%
    dplyr::select(dataset_name, dataset_reference) %>%
    tidyr::unnest(dataset_reference) %>%
    dplyr::distinct(dataset_name, dataset_reference) %>%
    tidyr::drop_na() %>%
    dplyr::left_join(
      dataset_reference_db,
      by = dplyr::join_by(dataset_reference == reference_detail)
    ) %>%
    dplyr::left_join(
      dataset_id,
      by = dplyr::join_by(dataset_name)
    ) %>%
    dplyr::distinct(
      dataset_id, reference_id
    )

  dataset_reference_unique <-
    dataset_reference_lookup %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetReferences") %>%
        dplyr::collect(),
      by = dplyr::join_by(
        dataset_id,
        reference_id
      )
    )

  add_to_db(
    conn = con,
    data = dataset_reference_unique,
    table_name = "DatasetReferences",
    overwrite_test = TRUE
  )
}
