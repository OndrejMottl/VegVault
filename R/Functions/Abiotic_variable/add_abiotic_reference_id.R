add_abiotic_reference_id <- function(data_source, con, mandatory = TRUE) {
  .data <- rlang::.data
  `%>%` <- magrittr::`%>%`

  assertthat::assert_that(
    assertthat::has_name(data_source, "var_reference"),
    msg = "data_source must have a column named var_reference"
  )

  variable_reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(.data$reference_detail) %>%
    dplyr::collect() %>%
    purrr::chuck("reference_detail")

  data_source_reference <-
    data_source %>%
    dplyr::distinct(.data$var_reference) %>%
    tidyr::unnest(.data$var_reference) %>%
    dplyr::filter(
      !.data$var_reference %in% variable_reference_db
    ) %>%
    dplyr::rename(reference_detail = .data$var_reference) %>%
    dplyr::mutate(
      mandatory = mandatory
    )

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
        dplyr::distinct(.data$var_reference) %>%
        tidyr::unnest(.data$var_reference),
      by = dplyr::join_by("reference_detail" == "var_reference")
    )

  return(data_source_reference_db)
}
