#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_trait_unit_rules() gives the schema columns", {
  res <-
    build_trait_unit_rules(
      list_conversions = build_trait_unit_conversions_fixture(),
      list_derivations = build_trait_derivations_fixture()
    )

  testthat::expect_named(res, c("unit_conversions", "trait_derivations"))

  testthat::expect_identical(
    base::names(purrr::chuck(res, "unit_conversions")),
    load_schema_columns("TraitUnitConversion")
  )

  testthat::expect_identical(
    base::names(purrr::chuck(res, "trait_derivations")),
    load_schema_columns("TraitDerivation")
  )

  testthat::expect_equal(base::nrow(purrr::chuck(res, "unit_conversions")), 6L)

  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "trait_derivations")),
    2L
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_trait_unit_rules() drops producer-only columns", {
  list_conversions <-
    build_trait_unit_conversions_fixture() |>
    purrr::map(
      .f = ~ dplyr::mutate(
        .x,
        verify_source_standardized = TRUE,
        verification_absolute_tolerance = 1e-6
      )
    )

  res <-
    build_trait_unit_rules(
      list_conversions = list_conversions,
      list_derivations = build_trait_derivations_fixture()
    )

  testthat::expect_false(
    "verify_source_standardized" %in%
      base::names(purrr::chuck(res, "unit_conversions"))
  )
})

testthat::test_that("build_trait_unit_rules() binds every table", {
  data_conversions <-
    build_trait_unit_conversions_fixture() |>
    purrr::chuck(1)

  res <-
    build_trait_unit_rules(
      list_conversions = list(
        a.csv = dplyr::slice(data_conversions, 1:2),
        b.csv = dplyr::slice(data_conversions, 3:6)
      ),
      list_derivations = build_trait_derivations_fixture()
    )

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "unit_conversions"), conversion_rule_key),
    dplyr::pull(data_conversions, conversion_rule_key)
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_trait_unit_rules() needs the schema columns", {
  list_conversions <-
    build_trait_unit_conversions_fixture() |>
    purrr::map(.f = ~ dplyr::select(.x, -"evidence"))

  testthat::expect_error(
    build_trait_unit_rules(
      list_conversions = list_conversions,
      list_derivations = build_trait_derivations_fixture()
    ),
    regexp = "evidence"
  )
})

testthat::test_that("build_trait_unit_rules() validates arguments", {
  testthat::expect_error(
    build_trait_unit_rules(
      list_conversions = build_trait_unit_conversions_fixture() |>
        purrr::chuck(1),
      list_derivations = build_trait_derivations_fixture()
    ),
    regexp = "list_conversions"
  )

  testthat::expect_error(
    build_trait_unit_rules(
      list_conversions = build_trait_unit_conversions_fixture(),
      list_derivations = list()
    ),
    regexp = "list_derivations"
  )
})
