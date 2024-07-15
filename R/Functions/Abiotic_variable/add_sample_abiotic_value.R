add_sample_abiotic_value <- function(
    data_source,
    con,
    sample_id,
    abiotic_variable_id) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_name",
        "abiotic_variable_name",
        "value"
      )
    ),
    msg = "data_source must contain columns: sample_name, abiotic_variable_name, value"
  )

  assertthat::assert_that(
    assertthat::has_name(
      sample_id,
      c(
        "sample_name",
        "sample_id"
      )
    ),
    msg = "sample_id must contain columns: sample_name, sample_id"
  )

  assertthat::assert_that(
    assertthat::has_name(
      abiotic_variable_id,
      c(
        "abiotic_variable_name",
        "abiotic_variable_id"
      )
    ),
    msg = "abiotic_variable_id must contain columns: abiotic_variable_name, abiotic_variable_id"
  )

  data_sample_value <-
    data_source %>%
    dplyr::left_join(
      sample_id,
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::left_join(
      abiotic_variable_id,
      by = dplyr::join_by(abiotic_variable_name)
    ) %>%
    dplyr::select(
      sample_id, abiotic_variable_id, 
      abiotic_value = value
    )

  data_sample_value_unique <-
    data_sample_value %>%
    dplyr::anti_join(
      dplyr::tbl(con, "AbioticData") %>%
        dplyr::select(sample_id, abiotic_variable_id) %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_id, abiotic_variable_id)
    )

  add_to_db(
    conn = con,
    data = data_sample_value_unique,
    table_name = "AbioticData",
    overwrite_test = TRUE
  )
}
