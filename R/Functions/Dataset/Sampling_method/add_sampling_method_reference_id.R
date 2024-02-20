add_sampling_method_reference_id <- function(data_source, con) {
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
    dplyr::select(sampling_reference) %>%
    tidyr::unnest(sampling_reference) %>%
    dplyr::distinct(sampling_reference) %>%
    tidyr::drop_na() %>%
    dplyr::rename(
      reference_detail = sampling_reference
    )

  sampling_method_reference_unique <-
    sampling_method_reference %>%
    dplyr::filter(
      !reference_detail %in% reference_detail_db
    )

  add_to_db(
    conn = con,
    data = sampling_method_reference_unique,
    table_name = "References"
  )

  reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      sampling_method_reference,
      by = dplyr::join_by(reference_detail)
    )

  return(reference_db)
}
