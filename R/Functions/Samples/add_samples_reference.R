add_samples_reference <- function(data_source, samples_reference_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source, c(
        "sample_name",
        "sample_reference"
      )
    ),
    msg = "data_source must have a column named sample_name and sample_reference"
  )

  sample_id_db <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::distinct(sample_id, sample_name) %>%
    dplyr::collect() 

  samples_reference_lookup <-
    data_source %>%
    dplyr::distinct(sample_name, sample_reference) %>%
    tidyr::drop_na() %>%
    dplyr::left_join(
      samples_reference_id,
      by = dplyr::join_by(sample_reference == reference_detail)
    ) %>%
    dplyr::left_join(
      sample_id_db,
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::select(sample_id, reference_id) 

  samples_reference_unique <-
    samples_reference_lookup %>%
    dplyr::anti_join(
      dplyr::tbl(con, "SampleReference") %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_id, reference_id)
    )

  add_to_db(
    conn = con,
    data = samples_reference_unique,
    table_name = "SampleReference",
    overwrite_test = TRUE
  )
}
