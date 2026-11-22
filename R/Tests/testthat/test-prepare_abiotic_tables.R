#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_abiotic_tables() validates arguments", {
  data_gridpoints <-
    build_test_position_inputs(list_source_tables = base::list()) |>
    purrr::chuck("data_gridpoints")

  list_variable <-
    base::list(name = "bio1", unit = "C", details = "temperature")

  data_references <-
    tibble::tibble(reference_detail = "Climate citation", mandatory = TRUE)

  testthat::expect_error(
    prepare_abiotic_tables(
      data_values = tibble::tibble(long = 10, lat = 50, value = 1),
      data_gridpoints = data_gridpoints,
      list_variable = list_variable,
      data_references = data_references,
      sel_age_rule = "sometimes",
      verbose = FALSE
    ),
    regexp = "sel_age_rule"
  )

  testthat::expect_error(
    prepare_abiotic_tables(
      data_values = tibble::tibble(long = 10, lat = 50, value = 1),
      data_gridpoints = data_gridpoints,
      list_variable = list_variable,
      data_references = data_references,
      sel_age_rule = "time_id",
      verbose = FALSE
    ),
    regexp = "time_id"
  )

  testthat::expect_error(
    prepare_abiotic_tables(
      data_values = tibble::tibble(long = 10, lat = 50, value = 1),
      data_gridpoints = data_gridpoints,
      list_variable = base::list(name = "bio1", details = "temperature"),
      data_references = data_references,
      sel_age_rule = "present",
      verbose = FALSE
    ),
    regexp = "unit"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_abiotic_tables() attaches present values", {
  data_gridpoints <-
    build_test_position_inputs(list_source_tables = base::list()) |>
    purrr::chuck("data_gridpoints")

  res <-
    prepare_abiotic_tables(
      data_values = tibble::tibble(
        long = c(10.001, 0.4999, 33.3),
        lat = c(50.004, 0.5, 33.3),
        value = c(7.5, NA_real_, 1)
      ),
      data_gridpoints = data_gridpoints,
      list_variable = base::list(
        name = "bio1",
        unit = "C (degree Celsius)",
        details = "mean annual air temperature"
      ),
      data_references = tibble::tibble(
        reference_detail = c("Citation A", "Citation B"),
        mandatory = TRUE
      ),
      sel_age_rule = "present",
      verbose = FALSE
    )

  testthat::expect_identical(
    purrr::map(.x = res, .f = base::names),
    purrr::map(.x = build_source_table_template(), .f = base::names)
  )

  data_values <-
    purrr::chuck(res, "abiotic_values") |>
    dplyr::arrange(sample_name)

  # The cell without a gridpoint is not stored; a missing value stays
  testthat::expect_equal(
    dplyr::pull(data_values, sample_name),
    c("geo_0.5_0.5_0", "geo_10_50_0")
  )
  testthat::expect_equal(
    dplyr::pull(data_values, abiotic_value),
    c(NA_real_, 7.5)
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "abiotic_variables"), measure_details),
    "mean annual air temperature"
  )
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "abiotic_variable_references")),
    2L
  )
})

testthat::test_that("prepare_abiotic_tables() reads palaeoclimate ages", {
  data_gridpoints <-
    build_test_position_inputs(list_source_tables = base::list()) |>
    purrr::chuck("data_gridpoints")

  res <-
    prepare_abiotic_tables(
      data_values = tibble::tibble(
        long = c(10, 10),
        lat = c(50, 50),
        time_id = c(15L, 20L),
        value = c(3, 4)
      ),
      data_gridpoints = data_gridpoints,
      list_variable = base::list(name = "bio1", unit = "C", details = "t"),
      data_references = tibble::tibble(
        reference_detail = "Citation",
        mandatory = TRUE
      ),
      sel_age_rule = "time_id",
      verbose = FALSE
    )

  # time_id 15 is age 500; time_id 20 is age 0, given by present-day data
  data_values <-
    purrr::chuck(res, "abiotic_values")

  testthat::expect_equal(
    dplyr::pull(data_values, sample_name),
    "geo_10_50_500"
  )
  testthat::expect_equal(dplyr::pull(data_values, abiotic_value), 3)
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_abiotic_tables() refuses two values per cell", {
  data_gridpoints <-
    build_test_position_inputs(list_source_tables = base::list()) |>
    purrr::chuck("data_gridpoints")

  testthat::expect_error(
    prepare_abiotic_tables(
      data_values = tibble::tibble(
        long = c(10.001, 9.999),
        lat = c(50, 50),
        value = c(1, 2)
      ),
      data_gridpoints = data_gridpoints,
      list_variable = base::list(name = "bio1", unit = "C", details = "t"),
      data_references = tibble::tibble(
        reference_detail = "Citation",
        mandatory = TRUE
      ),
      sel_age_rule = "present",
      verbose = FALSE
    ),
    regexp = "more than one value"
  )
})
