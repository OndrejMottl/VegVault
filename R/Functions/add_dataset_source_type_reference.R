add_dataset_source_type_reference <- function(data_source, con) {
  dataset_source_type_referecne <-
    data_source %>%
    dplyr::distinct(data_source_type_reference) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "References") %>%
        dplyr::collect(),
      by = dplyr::join_by(data_source_type_reference == reference_detail)
    ) %>%
    dplyr::rename(reference_detail = data_source_type_reference)

  add_to_db(
    conn = con,
    data = dataset_source_type_referecne,
    table_name = "References"
  )

  dataset_source_type_referecne_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(data_source_type_reference),
      by = dplyr::join_by(reference_detail == data_source_type_reference)
    )

  return(dataset_source_type_referecne_db)
}
