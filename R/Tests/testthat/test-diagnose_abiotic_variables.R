#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_variables() passes matching labels", {
  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = tibble::tibble(
        long = 14.1, lat = 50.1, age = 0, variable = "bio1", value = 8.5
      )
    )

  data_rules <-
    build_abiotic_test_rules() |>
    dplyr::filter(variable %in% c("bio1", "bio12"))

  res <-
    diagnose_abiotic_variables(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = data_rules
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, scope), c("bio1", "bio12"))

  testthat::expect_true(
    base::all(dplyr::pull(res, check_id) == "abiotic_variables")
  )

  testthat::expect_equal(dplyr::pull(res, status), c("pass", "pass"))

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c("C (degree Celsius)", "kg m-2 year-1")
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_variables() fails wrong labels", {
  # bio1 with the v1 unit, bio4 with another description, bio18 missing,
  #   HWSD2 without a description to compare, and bio99 without a rule
  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = tibble::tibble(
        long = 14.1, lat = 50.1, age = 0, variable = "bio1", value = 8.5
      ),
      data_variables = tibble::tribble(
        ~abiotic_variable_id, ~abiotic_variable_name, ~abiotic_variable_unit,
        ~measure_details,
        1L, "bio1", "C", "mean annual air temperature",
        2L, "bio4", "C/100 (hundredths of a degree Celsius)",
        "temperature seasonality, v1",
        3L, "bio12", "kg m-2 year-1", "annual precipitation amount",
        4L, "HWSD2", "Unitless", "HWSD-soil_group",
        5L, "bio99", "mm", "an invented variable"
      )
    )

  res <-
    diagnose_abiotic_variables(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = build_abiotic_test_rules()
    )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c("bio1", "bio4", "bio12", "bio18", "HWSD2", "bio99")
  )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("fail", "fail", "pass", "fail", "pass", "fail")
  )

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "unit")

  testthat::expect_match(vec_messages[2], "description")

  testthat::expect_match(vec_messages[4], "not in AbioticVariable")

  testthat::expect_match(vec_messages[6], "no contract")

  testthat::expect_equal(dplyr::pull(res, observed)[4], NA_character_)

  testthat::expect_equal(dplyr::pull(res, threshold)[1], "C (degree Celsius)")
})

testthat::test_that("diagnose_abiotic_variables() fails repeated names", {
  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = tibble::tibble(
        long = 14.1, lat = 50.1, age = 0, variable = "bio1", value = 8.5
      ),
      data_variables = tibble::tribble(
        ~abiotic_variable_id, ~abiotic_variable_name, ~abiotic_variable_unit,
        ~measure_details,
        1L, "bio1", "C (degree Celsius)", "mean annual air temperature",
        2L, "bio1", "C (degree Celsius)", "mean annual air temperature"
      )
    )

  res <-
    diagnose_abiotic_variables(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = dplyr::filter(build_abiotic_test_rules(), variable == "bio1")
    )

  testthat::expect_equal(dplyr::pull(res, status), "fail")

  testthat::expect_match(dplyr::pull(res, message), "2 rows")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_variables() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_abiotic_variables(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      ),
      data_rules = build_abiotic_test_rules()
    ),
    regexp = "not the database of the build manifest"
  )
})
