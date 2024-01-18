add_trait_value <- function(
    data_source,
    dataset_id,
    samples_id,
    traits_id,
    taxa_id,
    con) {
  traits_value <-
    data_source %>%
    dplyr::left_join(
      dataset_id,
      by = dplyr::join_by(dataset_name)
    ) %>%
    dplyr::left_join(
      samples_id,
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::left_join(
      traits_id,
      by = dplyr::join_by(trait_name)
    ) %>%
    dplyr::left_join(
      taxa_id,
      by = dplyr::join_by(taxon_name)
    ) %>%
    dplyr::select(
      trait_id, dataset_id, sample_id,
      taxon_id,
      trait_value
    )

  traits_value_unique <-
    traits_value %>%
    dplyr::anti_join(
      dplyr::tbl(con, "TraitsValue") %>%
        dplyr::select(trait_id, dataset_id, sample_id, taxon_id) %>%
        dplyr::collect(),
      by = dplyr::join_by(trait_id, dataset_id, sample_id, taxon_id)
    )

  add_to_db(
    conn = con,
    data = traits_value_unique,
    table_name = "TraitsValue",
    overwrite_test = TRUE
  )
}
