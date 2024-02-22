add_abiotic_variable_id <- function(
    data_source,
    con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "abiotic_variable_name",
        "var_unit",
        "var_detail"
      )
    ),
    msg = "data_source must contain columns: abiotic_variable_name, var_unit, and var_detail"
  )

  abiotic_variable_name_db <-
    dplyr::tbl(con, "AbioticVariable") %>%
    dplyr::distinct(abiotic_variable_name) %>%
    dplyr::collect() %>%
    purrr::chuck("abiotic_variable_name")

  data_abiotic_variable <-
    data_source %>%
    dplyr::select(
      abiotic_variable_name,
      abiotic_variable_unit = var_unit,
      measure_details = var_detail
    ) %>%
    dplyr::distinct() %>%
    tidyr::drop_na(abiotic_variable_name, abiotic_variable_unit)

  data_abiotic_variable_unique <-
    data_abiotic_variable %>%
    dplyr::filter(
      !abiotic_variable_name %in% abiotic_variable_name_db
    )

  add_to_db(
    conn = con,
    data = data_abiotic_variable_unique,
    table_name = "AbioticVariable"
  )

  abiotic_variabe_id <-
    dplyr::tbl(con, "AbioticVariable") %>%
    dplyr::distinct(abiotic_variable_id, abiotic_variable_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_abiotic_variable %>%
        dplyr::distinct(abiotic_variable_name),
      by = dplyr::join_by(abiotic_variable_name)
    )

  return(abiotic_variabe_id)
}
