add_sampling_reference <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "sampling_reference"),
    msg = "data_source must have column 'sampling_reference'"
  )

  reference_detail_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::chuck("reference_detail")

  sampling_method_reference <-
    data_source %>%
    dplyr::distinct(sampling_reference) %>%
    tidyr::drop_na() %>%
    dplyr::rename(
      reference_detail = sampling_reference
    ) %>%
    dplyr::filter(
      !reference_detail %in% reference_detail_db
    )

  add_to_db(
    conn = con,
    data = sampling_method_reference,
    table_name = "References"
  )

  reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(sampling_reference),
      by = dplyr::join_by(reference_detail == sampling_reference)
    )

  return(reference_db)
}
