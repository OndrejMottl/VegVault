add_dataset_reference <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "dataset_reference"),
    msg = "data_source must have column 'reference_detail'"
  )

  reference_detail_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::chuck("reference_detail")

  reference <-
    fossilpol_dataset_raw %>%
    dplyr::distinct(dataset_reference) %>%
    tidyr::drop_na() %>%
    dplyr::rename(
      reference_detail = dataset_reference
    ) %>%
    dplyr::filter(
      !reference_detail %in% reference_detail_db
    )

  add_to_db(
    conn = con,
    data = reference,
    table_name = "References"
  )

  reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      fossilpol_dataset_raw %>%
        dplyr::distinct(dataset_reference),
      by = dplyr::join_by(reference_detail == dataset_reference)
    )

  return(reference_db)
}
