add_abiotic_reference <- function(data_source, abiotic_reference_id, con) {
  .data <- rlang::.data
  `%>%` <- magrittr::`%>%`

  data_abiotic_variable_id <-
    dplyr::tbl(con, "AbioticVariable") %>%
    dplyr::distinct(
      .data$abiotic_variable_id,
      .data$abiotic_variable_name
    ) %>%
    dplyr::collect()

  data_abiotic_reference_lookup <-
    data_source %>%
    dplyr::distinct(.data$abiotic_variable_name, .data$var_reference) %>%
    tidyr::unnest(.data$var_reference) %>%
    tidyr::drop_na() %>%
    dplyr::left_join(
      data_abiotic_variable_id,
      by = dplyr::join_by("abiotic_variable_name")
    ) %>%
    dplyr::left_join(
      abiotic_reference_id,
      by = dplyr::join_by("var_reference" == "reference_detail")
    ) %>%
    dplyr::select("abiotic_variable_id", "reference_id")

  data_abiotic_reference_unique <-
    data_abiotic_reference_lookup %>%
    dplyr::anti_join(
      dplyr::tbl(con, "AbioticVariableReference") %>%
        dplyr::collect(),
      by = dplyr::join_by("abiotic_variable_id", "reference_id")
    )

  add_to_db(
    data = data_abiotic_reference_unique,
    conn = con,
    table_nam = "AbioticVariableReference",
    overwrite_test = TRUE
  )
}
