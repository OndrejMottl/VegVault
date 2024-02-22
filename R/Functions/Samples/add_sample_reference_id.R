add_sample_reference_id <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "sample_reference"),
    msg = "data_source must have a column named sample_reference"
  )

  reference_detail_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::pluck("reference_detail")

  samples_reference <-
    data_source %>%
    dplyr::distinct(sample_reference) %>%
    tidyr::drop_na() %>%
    dplyr::rename(
      reference_detail = sample_reference
    ) %>%
    dplyr::filter(
      !reference_detail %in% reference_detail_db
    )

  add_to_db(
    conn = con,
    data = samples_reference,
    table_name = "References"
  )

  samples_reference_id <-
    dplyr::tbl(con, "References") %>%
    dplyr::select(reference_id, reference_detail) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(sample_reference),
      by = dplyr::join_by(reference_detail == sample_reference)
    )

  return(samples_reference_id)
}
