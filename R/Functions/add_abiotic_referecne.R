add_abiotic_referecne <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "variable_reference"),
    msg = "data_source must have a column named variable_reference"
  )

  variable_reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::chuck("reference_detail")

  data_source_reference <-
    data_source %>%
    dplyr::distinct(variable_reference) %>%
    dplyr::filter(
      !variable_reference %in% variable_reference_db
    ) %>%
    dplyr::rename(reference_detail = variable_reference)

  add_to_db(
    conn = con,
    data = data_source_reference,
    table_name = "References"
  )

  data_source_reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(variable_reference),
      by = dplyr::join_by(reference_detail == variable_reference)
    )

  return(data_source_reference_db)
}
