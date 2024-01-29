add_trait_value <- function(
    data_source,
    dataset_id,
    samples_id,
    traits_id,
    taxa_id,
    con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "dataset_name",
        "sample_name",
        "trait_name",
        "taxon_name",
        "trait_value"
      )
    ),
    msg = "data_source must have a column named dataset_name, sample_name, trait_name, taxon_name, and trait_value"
  )

  assertthat::assert_that(
    assertthat::has_name(
      dataset_id,
      c(
        "dataset_id",
        "dataset_name"
      )
    ),
    msg = "dataset_id must have a column named dataset_id and dataset_name"
  )

  assertthat::assert_that(
    assertthat::has_name(
      samples_id,
      c(
        "sample_id",
        "sample_name"
      )
    ),
    msg = "samples_id must have a column named sample_id and sample_name"
  )

  assertthat::assert_that(
    assertthat::has_name(
      traits_id,
      c(
        "trait_id",
        "trait_name"
      )
    ),
    msg = "traits_id must have a column named trait_id and trait_name"
  )

  assertthat::assert_that(
    assertthat::has_name(
      taxa_id,
      c(
        "taxon_id",
        "taxon_name"
      )
    ),
    msg = "taxa_id must have a column named taxon_id and taxon_name"
  )

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
