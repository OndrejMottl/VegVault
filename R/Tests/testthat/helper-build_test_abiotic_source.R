# The source tables of one abiotic variable for the tests: the variable
#   with its unit and details, one mandatory reference, and one value per
#   given sample name (the template elsewhere empty).
build_test_abiotic_source <- function(
  name_variable,
  vec_sample_names,
  vec_values,
  unit = "C (degree Celsius)",
  details = "test variable",
  reference = "Climate citation"
) {
  res <-
    purrr::list_modify(
      build_source_table_template(),
      abiotic_variables = tibble::tibble(
        abiotic_variable_name = name_variable,
        abiotic_variable_unit = unit,
        measure_details = details
      ),
      abiotic_variable_references = tibble::tibble(
        abiotic_variable_name = name_variable,
        reference_detail = reference,
        mandatory = TRUE
      ),
      abiotic_values = tibble::tibble(
        sample_name = vec_sample_names,
        abiotic_variable_name = name_variable,
        abiotic_value = vec_values
      )
    )

  return(res)
}
