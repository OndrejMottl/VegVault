add_sample_reference <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "reference_source"),
    msg = "data_source must have a column named reference_source"
  )

  reference_detail_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::pluck("reference_detail")

  samples_reference <-
    data_source %>%
    dplyr::distinct(reference_source) %>%
    tidyr::drop_na() %>%
    dplyr::rename(
      reference_detail = reference_source
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
        dplyr::distinct(reference_source),
      by = dplyr::join_by(reference_detail == reference_source)
    )

  return(samples_reference_id)
}
