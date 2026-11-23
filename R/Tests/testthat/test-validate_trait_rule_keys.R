#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

list_rules_fixture <-
  build_trait_unit_rules(
    list_conversions = build_trait_unit_conversions_fixture(),
    list_derivations = build_trait_derivations_fixture()
  )

list_traits_fixture <-
  list(
    try_traits = build_try_traits_fixture(),
    bien_traits = build_bien_traits_fixture()
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_trait_rule_keys() passes the fixtures", {
  testthat::expect_invisible(
    res <-
      validate_trait_rule_keys(
        list_trait_artefacts = list_traits_fixture,
        list_rules = list_rules_fixture
      )
  )

  testthat::expect_named(res, c("artefact_id", "rule_column", "n_keys"))

  testthat::expect_equal(base::nrow(res), 4L)

  # The TRY fixture cites three conversion rules and no derivation rule
  testthat::expect_equal(
    res |>
      dplyr::filter(
        artefact_id == "try_traits",
        rule_column == "conversion_rule_key"
      ) |>
      dplyr::pull(n_keys),
    3L
  )

  testthat::expect_equal(
    res |>
      dplyr::filter(rule_column == "derivation_rule_key") |>
      dplyr::pull(n_keys),
    c(0L, 0L)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_trait_rule_keys() finds a missing rule", {
  list_rules_short <-
    purrr::modify_in(
      list_rules_fixture,
      .where = "unit_conversions",
      .f = ~ dplyr::filter(.x, conversion_rule_key != "bien_height")
    )

  testthat::expect_error(
    validate_trait_rule_keys(
      list_trait_artefacts = list_traits_fixture,
      list_rules = list_rules_short
    ),
    regexp = "bien_traits.*conversion_rule_key.*bien_height"
  )
})

testthat::test_that("validate_trait_rule_keys() finds a missing derivation", {
  list_traits_derived <-
    purrr::modify_in(
      list_traits_fixture,
      .where = "try_traits",
      .f = ~ purrr::map(
        .x = .x,
        .f = ~ dplyr::mutate(
          .x,
          derivation_rule_key = c("sla_to_lma", NA, NA, "unknown_rule")
        )
      )
    )

  testthat::expect_error(
    validate_trait_rule_keys(
      list_trait_artefacts = list_traits_derived,
      list_rules = list_rules_fixture
    ),
    regexp = "try_traits.*derivation_rule_key.*unknown_rule"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_trait_rule_keys() validates arguments", {
  testthat::expect_error(
    validate_trait_rule_keys(
      list_trait_artefacts = build_try_traits_fixture(),
      list_rules = list_rules_fixture
    ),
    regexp = "list_trait_artefacts"
  )

  testthat::expect_error(
    validate_trait_rule_keys(
      list_trait_artefacts = list_traits_fixture,
      list_rules = purrr::chuck(list_rules_fixture, "unit_conversions")
    ),
    regexp = "list_rules"
  )

  list_traits_bad <-
    purrr::modify_in(
      list_traits_fixture,
      .where = "bien_traits",
      .f = ~ purrr::map(
        .x = .x,
        .f = ~ dplyr::select(.x, -"conversion_rule_key")
      )
    )

  testthat::expect_error(
    validate_trait_rule_keys(
      list_trait_artefacts = list_traits_bad,
      list_rules = list_rules_fixture
    ),
    regexp = "conversion_rule_key"
  )
})
