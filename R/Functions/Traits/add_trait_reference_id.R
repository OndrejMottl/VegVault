add_trait_reference_id <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "trait_reference"),
    msg = "data_source must have a column named trait_reference"
  )

  reference_detail_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::pluck("reference_detail")

  trait_reference <-
    data_source %>%
    dplyr::distinct(trait_reference) %>%
    tidyr::drop_na() %>%
    dplyr::rename(
      reference_detail = trait_reference
    ) %>%
    dplyr::filter(
      !reference_detail %in% reference_detail_db
    )

  add_to_db(
    conn = con,
    data = trait_reference,
    table_name = "References"
  )

  trait_reference_id <-
    dplyr::tbl(con, "References") %>%
    dplyr::select(reference_id, reference_detail) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(trait_reference),
      by = dplyr::join_by(reference_detail == trait_reference)
    )

  return(trait_reference_id)
}
