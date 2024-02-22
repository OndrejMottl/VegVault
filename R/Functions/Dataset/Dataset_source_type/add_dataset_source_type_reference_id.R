add_dataset_source_type_reference_id <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "data_source_type_reference"),
    msg = "data_source must have a column named data_source_type_reference"
  )

  dataset_reference_detail_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::pluck("reference_detail")

  dataset_source_type_referecne <-
    data_source %>%
    dplyr::select(data_source_type_reference) %>%
    tidyr::unnest(data_source_type_reference) %>%
    dplyr::distinct(data_source_type_reference) %>%
    tidyr::drop_na() %>%
    dplyr::filter(
      !data_source_type_reference %in% dataset_reference_detail_db
    ) %>%
    dplyr::rename(reference_detail = data_source_type_reference)

  add_to_db(
    conn = con,
    data = dataset_source_type_referecne,
    table_name = "References"
  )

  dataset_source_type_referecne_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::select(data_source_type_reference) %>%
        tidyr::unnest(data_source_type_reference) %>%
        dplyr::distinct(data_source_type_reference),
      by = dplyr::join_by(reference_detail == data_source_type_reference)
    )

  return(dataset_source_type_referecne_db)
}
