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

  data_abiotic_variable_id_db <-
    add_abiotic_variable_id(
      data_source = data_source,
      con = con
    )

  data_reference_id_db <-
    add_abiotic_referecne_id(
      data_source = data_source,
      con = con
    )

  add_abiotic_referecne(
    data_source = data_source,
    abiotic_reference_id = data_reference_id_db,
    con = con
  )

  return(data_abiotic_variable_id_db)
}
