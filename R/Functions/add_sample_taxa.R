add_sample_taxa <- function(data_source, samples_id, taxa_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_name",
        "taxon_name",
        "value"
      )
    ),
    msg = "data_source must have columns 'sample_name', 'taxon_name' and 'value'"
  )
  assertthat::assert_that(
    assertthat::has_name(samples_id, "sample_name"),
    msg = "samples_id must have column 'sample_name'"
  )
  assertthat::assert_that(
    assertthat::has_name(taxa_id, "taxon_name"),
    msg = "taxa_id must have column 'taxon_name'"
  )

  sample_taxa <-
    data_source %>%
    dplyr::left_join(
      samples_id,
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::left_join(
      taxa_id,
      by = dplyr::join_by(taxon_name)
    ) %>%
    dplyr::select(
      sample_id, taxon_id, value
    )

  sample_taxa_unique <-
    sample_taxa %>%
    dplyr::anti_join(
      dplyr::tbl(con, "SampleTaxa") %>%
        dplyr::select(sample_id, taxon_id) %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_id, taxon_id)
    )

  add_to_db(
    conn = con,
    data = sample_taxa_unique,
    table_name = "SampleTaxa",
    overwrite_test = TRUE
  )
}
