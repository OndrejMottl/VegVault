add_dataset_source_type_reference <- function(
    data_source,
    data_source_type_id,
    con) {
  dataset_source_type_referecne_db <-
    add_dataset_source_type_reference_id(
      data_source = data_source,
      con = con
    )

  dataset_source_type_referecne_lookup <-
    data_source %>%
    dplyr::select(dataset_source_type, data_source_type_reference) %>%
    tidyr::unnest(data_source_type_reference) %>%
    dplyr::distinct(dataset_source_type, data_source_type_reference) %>%
    dplyr::left_join(
      dataset_source_type_referecne_db,
      by = dplyr::join_by(data_source_type_reference == reference_detail)
    ) %>%
    dplyr::left_join(
      data_source_type_id,
      by = dplyr::join_by(dataset_source_type)
    ) %>%
    dplyr::distinct(
      data_source_type_id,
      reference_id
    )

  dataset_source_type_referecne_lookup_unique <-
    dataset_source_type_referecne_lookup %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetSourceTypeReference") %>%
        dplyr::collect(),
      by = dplyr::join_by(
        data_source_type_id,
        reference_id
      )
    )

  add_to_db(
    conn = con,
    data = dataset_source_type_referecne_lookup_unique,
    table_name = "DatasetSourceTypeReference",
    overwrite_test = TRUE
  )
}
