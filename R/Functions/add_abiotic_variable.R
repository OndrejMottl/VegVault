add_abiotic_variable <- function(
    data_source,
    con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "abiotic_variable_name",
        "var_unit",
        "var_reference",
        "var_detail"
      )
    ),
    msg = "data_source must contain columns: abiotic_variable_name, var_unit, var_reference, var_detail"
  )

  data_abiotic_variable <-
    data_source %>%
    dplyr::select(
      abiotic_variable_name,
      var_unit,
      var_reference,
      var_detail
    ) %>%
    dplyr::distinct(
      abiotic_variable_name,
      var_unit,
      var_reference,
      var_detail
    ) %>%
    dplyr::rename(
      variable_reference = var_reference,
    )

  data_reference <-
    add_abiotic_referecne(
      data_source = data_abiotic_variable,
      con = con
    )

  data_abiotic_variable_with_reference <-
    data_abiotic_variable %>%
    dplyr::left_join(
      data_reference,
      by = dplyr::join_by(variable_reference == reference_detail)
    ) %>%
    dplyr::select(-variable_reference) %>%
    dplyr::select(
      abiotic_variable_name,
      abiotic_variable_unit = var_unit,
      abiotic_variable_reference = reference_id,
      measure_details = var_detail
    ) %>%
    dplyr::distinct()

  data_abiotic_variable_with_reference_unique <-
    data_abiotic_variable_with_reference %>%
    dplyr::anti_join(
      dplyr::tbl(con, "AbioticVariable") %>%
        dplyr::distinct(abiotic_variable_name) %>%
        dplyr::collect(),
      by = dplyr::join_by(abiotic_variable_name)
    )

  add_to_db(
    conn = con,
    data = data_abiotic_variable_with_reference_unique,
    table_name = "AbioticVariable"
  )

  abiotic_variabe_id <-
    dplyr::tbl(con, "AbioticVariable") %>%
    dplyr::select(abiotic_variable_id, abiotic_variable_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(abiotic_variable_name),
      by = dplyr::join_by(abiotic_variable_name)
    )

  return(abiotic_variabe_id)
}
