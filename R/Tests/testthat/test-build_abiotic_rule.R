#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_abiotic_rule() fills the defaults", {
  res <-
    build_abiotic_rule(
      artefact_id = "hwsd_soil",
      variable = "HWSD2",
      unit = "Unitless",
      details = NA,
      age_min = -Inf,
      age_max = Inf,
      list_checks = base::list(finite = TRUE)
    )

  testthat::expect_equal(base::nrow(res), 1L)

  testthat::expect_named(
    res,
    c(
      "artefact_id", "variable", "unit", "details", "age_min", "age_max",
      "range_min", "range_max", "flag_min_inclusive", "flag_max_inclusive",
      "list_forbidden", "list_allowed", "flag_whole_number"
    )
  )

  testthat::expect_equal(dplyr::pull(res, details), NA_character_)

  testthat::expect_equal(dplyr::pull(res, range_min), -Inf)

  testthat::expect_equal(dplyr::pull(res, range_max), Inf)

  testthat::expect_true(dplyr::pull(res, flag_min_inclusive))

  testthat::expect_true(dplyr::pull(res, flag_max_inclusive))

  testthat::expect_equal(
    dplyr::pull(res, list_forbidden),
    base::list(base::numeric(0))
  )

  testthat::expect_equal(
    dplyr::pull(res, list_allowed),
    base::list(base::numeric(0))
  )

  testthat::expect_false(dplyr::pull(res, flag_whole_number))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_abiotic_rule() keeps the contract checks", {
  res <-
    build_abiotic_rule(
      artefact_id = "chelsa_neoclimate",
      variable = "bio4",
      unit = "C/100 (hundredths of a degree Celsius)",
      details = "temperature seasonality",
      age_min = 0,
      age_max = 0,
      list_checks = base::list(
        range = base::list(min = 0L, max = 3000L, min_inclusive = FALSE),
        forbidden_values = base::list(6553.5),
        allowed_values = c(1L, 2L),
        whole_number = TRUE
      )
    )

  testthat::expect_equal(dplyr::pull(res, range_min), 0)

  testthat::expect_type(dplyr::pull(res, range_max), "double")

  testthat::expect_false(dplyr::pull(res, flag_min_inclusive))

  testthat::expect_true(dplyr::pull(res, flag_max_inclusive))

  testthat::expect_equal(dplyr::pull(res, list_forbidden), base::list(6553.5))

  testthat::expect_equal(dplyr::pull(res, list_allowed), base::list(c(1, 2)))

  testthat::expect_true(dplyr::pull(res, flag_whole_number))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_abiotic_rule() refuses reversed ages", {
  testthat::expect_error(
    build_abiotic_rule(
      artefact_id = "chelsa_neoclimate",
      variable = "bio1",
      unit = "C (degree Celsius)",
      details = "mean annual air temperature",
      age_min = 500,
      age_max = 0,
      list_checks = base::list()
    ),
    regexp = "age_min"
  )
})
